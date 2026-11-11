require_relative 'integration_test'

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
      errors = page.driver.browser.logs.get(:browser).select { |entry| entry.level == 'SEVERE' }
      assert_empty errors.map(&:message)
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
end
