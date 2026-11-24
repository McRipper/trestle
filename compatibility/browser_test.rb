require_relative 'integration_test'

# Some Chrome versions report a detached document node as UnknownError instead
# of StaleElementReferenceError. Normalize only that message so Capybara applies
# its usual bounded element reload, without retrying a whole authentication flow.
module CompatibilityDetachedChromeNode
  def execute(...)
    super
  rescue Selenium::WebDriver::Error::UnknownError => error
    raise unless error.message.include?('Node with given id does not belong to the document')

    raise Selenium::WebDriver::Error::StaleElementReferenceError, error.message
  end
end

Selenium::WebDriver::Remote::Bridge.prepend(CompatibilityDetachedChromeNode)

Capybara.register_driver :compatibility_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument '--headless'
  options.add_argument '--window-size=1400,1400'
  options.add_argument '--no-sandbox' if ENV['CI'] == 'true'
  options.add_option 'goog:loggingPrefs', browser: 'ALL'
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

class IntegrationTest
  def with_chrome
    previous_csrf = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    Capybara.current_driver = :compatibility_chrome
    yield
  rescue Exception
    File.write(File.expand_path('logs/browser-failure.html', __dir__), page.html)
    page.save_screenshot(File.expand_path('tmp/browser-failure.png', __dir__))
    raise
  ensure
    Capybara.current_session.driver.quit if Capybara.current_driver == :compatibility_chrome
    Capybara.current_driver = :rack_test
    ActionController::Base.allow_forgery_protection = previous_csrf
  end

  def test_browser_translations_and_direct_uploads
    with_chrome do
      login
      assert_selector '.userbox .name', text: 'Admin Test'
      visit '/admin/articles/new'
      assert_text 'New Article'
      fill_in 'article_title_en', with: 'Browser article'
      within all('.mobility')[0] do
        find('.dropdown-toggle').click
        find('.dropdown-item', text: 'IT').click
      end
      fill_in 'article_title_it', with: 'Articolo dal browser'
      attach_file 'article[cover]', File.expand_path('fixtures/document.txt', __dir__)
      attach_file 'article[documents][]', File.expand_path('fixtures/document.txt', __dir__)
      click_button 'Save Article'
      assert_text 'successfully created'
      record = Article.order(:id).last
      assert_equal 'Articolo dal browser', record.title_it
      assert record.cover.attached?
      assert_equal 1, record.documents.count
      assert_chrome_has_no_errors
    end
  end

  def test_browser_otp_enrollment_and_recovery
    with_chrome do
      login
      visit '/admin/otp'
      fill_in 'Current password', with: 'password'
      click_button 'Set up authenticator app'
      find('summary', text: 'Enter a setup key manually').click
      secret = find('details code').text
      fill_in 'Authentication code', with: ROTP::TOTP.new(secret).now
      click_button 'Confirm and enable'
      assert_text 'Save your recovery codes'
      codes = all('li code').map(&:text)
      assert_equal 10, codes.size
      click_link 'I have saved my codes'
      visit '/admin/logout'
      login
      assert_current_path '/admin/otp/challenge'
      click_link 'Use a recovery code'
      fill_in 'Authentication or recovery code', with: codes.first
      click_button 'Verify and sign in'
      assert_selector '.userbox .name', text: 'Admin Test'
      visit '/admin/logout'
      login
      click_link 'Use a recovery code'
      fill_in 'Authentication or recovery code', with: codes.first
      click_button 'Verify and sign in'
      assert_text 'invalid, expired or already used'
      assert_current_path '/admin/otp/challenge', ignore_query: true
    end
  end

  def test_browser_tinymce_precompiled_assets_and_persistence
    with_chrome do
      login
      visit '/admin/articles/new'
      fill_in 'article_title_en', with: 'Rich article'

      default_editor = tinymce_toolbar('article_rich_text')
      summary_editor = tinymce_toolbar('article_summary')
      assert_equal '8', page.evaluate_script('tinymce.majorVersion')
      assert_equal 2, page.evaluate_script('tinymce.get().length')
      assert_equal 'flex', page.evaluate_script(<<~JS)
        getComputedStyle(document.querySelector('#article_rich_text + .tox .tox-toolbar__group')).display
      JS
      assert_selector 'link[rel="stylesheet"][href*="tinymce"][href*="skin"]', visible: :all
      assert_selector 'script[src*="/assets-"][src*="trestle/tinymce-"]', visible: :all
      assert default_editor.has_selector?('button[aria-label="Bullet list"]')
      assert summary_editor.has_no_selector?('button[aria-label="Bold"]')
      type_in_tinymce('article_rich_text', 'Formatted from Chrome')
      page.execute_script(<<~JS)
        const editor = tinymce.get('article_rich_text')
        editor.selection.select(editor.getBody(), true)
      JS
      default_editor.find('button[aria-label="Bold"]').click
      within_frame(find('#article_rich_text_ifr')) { assert_selector 'strong', text: 'Formatted from Chrome' }

      summary_editor.find('button[aria-label="Insert/edit link"]').click
      within('.tox-dialog') do
        fill_in 'URL', with: 'https://example.com/article'
        fill_in 'Text to display', with: 'Separate editor link'
        click_button 'Save'
      end
      click_button 'Save Article'

      assert_text 'successfully created'
      record = Article.sole
      assert_equal 'Rich article', record.title_en
      assert_equal 'Formatted from Chrome', Nokogiri::HTML.fragment(record.rich_text).at_css('strong')&.text
      link = Nokogiri::HTML.fragment(record.summary).at_css('a')
      assert_equal 'Separate editor link', link&.text
      assert_equal 'https://example.com/article', link['href']

      visit "/admin/articles/#{record.id}/edit"
      within_frame(find('#article_rich_text_ifr')) { assert_selector 'strong', text: 'Formatted from Chrome' }
      within_frame(find('#article_summary_ifr')) { assert_link 'Separate editor link', href: 'https://example.com/article' }
      assert_chrome_has_no_errors
    end
  end

  def test_browser_tinymce_reinitializes_after_validation_and_turbo_navigation
    record = article
    with_chrome do
      login
      visit "/admin/articles/#{record.id}/edit"
      tinymce_toolbar('article_rich_text')
      page.execute_script('window.compatibilityFirstEditor = tinymce.get("article_rich_text")')

      type_in_tinymce('article_rich_text', 'Kept after validation')
      fill_in 'article_title_en', with: ''
      click_button 'Save Article'
      assert_selector '.alert-danger', text: 'Please correct the errors below.'
      assert_nil record.reload.rich_text
      tinymce_toolbar('article_rich_text')
      within_frame(find('#article_rich_text_ifr')) { assert_text 'Kept after validation' }
      assert page.evaluate_script('window.compatibilityFirstEditor && window.compatibilityFirstEditor !== tinymce.get("article_rich_text")')

      click_link 'Articles', href: '/admin/articles', match: :first
      assert_current_path '/admin/articles'
      assert_no_selector '.tox-tinymce'
      assert_equal 0, page.evaluate_script('tinymce.get().length')

      page.go_back
      assert_current_path "/admin/articles/#{record.id}/edit"
      assert_tinymce_editors
      assert page.evaluate_script('Boolean(window.compatibilityFirstEditor)')

      click_link 'Articles', href: '/admin/articles', match: :first
      assert_current_path '/admin/articles'
      find('tr', text: record.title_en).click
      assert_tinymce_editors
      within_frame(find('#article_rich_text_ifr')) { assert_no_text 'Kept after validation' }
      failed_update_url = URI(page.current_url).merge("/admin/articles/#{record.id}")
      assert_chrome_has_no_errors(except: /\A#{Regexp.escape(failed_update_url.to_s)} - Failed to load resource: the server responded with a status of 422\b/)
    end
  end

  private

  def assert_tinymce_editors
    %w[article_rich_text article_summary].each do |field_id|
      assert_selector "##{field_id}_ifr", count: 1
      tinymce_toolbar(field_id)
    end
    assert_equal 2, page.evaluate_script('tinymce.get().length')
  end

  def tinymce_toolbar(field_id)
    within_frame(find("##{field_id}_ifr")) { assert_selector 'body[contenteditable="true"]' }
    find("##{field_id} + .tox .tox-editor-header")
  end

  def type_in_tinymce(field_id, text)
    within_frame(find("##{field_id}_ifr")) do
      editable = find('body[contenteditable="true"]')
      editable.click
      editable.send_keys(text)
      assert_text text
    end
  end

  def assert_chrome_has_no_errors(except: nil)
    errors = page.driver.browser.logs.get(:browser).select { |entry| entry.level == 'SEVERE' }
    messages = errors.map(&:message)
    messages.reject! { |message| except.match?(message) } if except
    assert_empty messages
  end
end
