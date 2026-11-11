require_relative 'schema'
require 'minitest/autorun'
require 'capybara/minitest'
require 'capybara/dsl'
require 'timecop'

Capybara.app = Rails.application

class IntegrationTest < Minitest::Test
  include Capybara::DSL
  include Capybara::Minitest::Assertions

  def setup
    Capybara.reset_sessions!
    ActiveRecord::Base.connection.tables.reject { |name| %w[schema_migrations ar_internal_metadata].include?(name) }.each do |name|
      ActiveRecord::Base.connection.execute("TRUNCATE TABLE #{ActiveRecord::Base.connection.quote_table_name(name)} RESTART IDENTITY CASCADE")
    end
    Trestle.config.auth.backend = :basic
    @user = Administrator.create!(email: 'admin@example.com', password: 'password', first_name: 'Admin', last_name: 'Test')
  end

  def teardown
    Capybara.reset_sessions!
  end

  def login(token: nil)
    visit '/admin/login'
    fill_in 'Email', with: @user.email
    fill_in 'Password', with: 'password'
    click_button 'Login'
    if token && page.has_current_path?('/admin/otp/challenge')
      fill_in 'Authentication code', with: token
      click_button 'Verify and sign in'
    end
  end

  def article(title = 'English title')
    Article.create!(title_en: title, title_it: 'Titolo italiano', body_en: 'English body', body_it: 'Testo italiano')
  end

  def enable_otp
    secret = Administrator.otp_random_secret
    Timecop.freeze(Time.current - 60) do
      @user.enable_otp!(secret: secret, code: ROTP::TOTP.new(secret).now, expected_signature: @user.otp_session_signature)
    end
  end

  def test_every_engine_eager_loads
    Rails.application.eager_load!
    assert_includes Trestle::ResourceController.ancestors, Trestle::ActiveStorage::ControllerConcern
    assert Trestle::GoodJob::GoodJobAdmin
    assert Trestle.lookup(:articles).respond_to?(:search)
  end

  def test_login_and_logout
    visit '/admin/articles'
    assert_current_path '/admin/login'
    login
    assert_text 'Admin Test'
    click_link 'Logout'
    visit '/admin/articles'
    assert_current_path '/admin/login'
  end

  def test_otp_required_when_enabled
    enable_otp
    login
    assert_current_path '/admin/otp/challenge'
    login(token: 'invalid')
    assert_current_path '/admin/otp/challenge'
    assert_text 'invalid, expired or already used'
    login(token: @user.otp_code)
    assert_current_path '/admin/administrators'
  end

  def test_search_filters_resources
    article('Unique search result')
    article('Unrelated article')
    login
    visit '/admin/articles?q=Unique'
    assert_text 'Unique search result'
    refute_text 'Unrelated article'
  end

  def test_localized_fields_render_and_update
    record = article
    login
    visit "/admin/articles/#{record.id}/edit"
    assert_selector 'input[name="article[title_en]"]'
    assert_selector 'input[name="article[title_it]"]'
    assert_selector 'textarea[name="article[body_it]"]'
    assert_selector 'input[name="article[published_it]"][type="checkbox"]'
    fill_in 'article_title_it', with: 'Aggiornato'
    click_button 'Save Article'
    assert_equal 'Aggiornato', record.reload.title_it
    assert_equal 'English title', record.title_en
  end

  def test_file_upload_and_delete_with_integer_blob_ids
    record = article
    login
    visit "/admin/articles/#{record.id}/edit"
    attach_file 'article[cover]', File.expand_path('fixtures/document.txt', __dir__)
    attach_file 'article[documents][]', File.expand_path('fixtures/document.txt', __dir__)
    click_button 'Save Article'
    assert record.reload.cover.attached?
    assert_equal 1, record.documents.count
    blob_id = record.documents.first.blob_id
    assert_kind_of Integer, blob_id

    visit "/admin/articles/#{record.id}/edit"
    assert_selector "input[type=checkbox][name='article[delete_documents_#{blob_id}]']", count: 1
    check 'Delete cover'
    check 'Delete this document'
    click_button 'Save Article'
    refute record.reload.cover.attached?
    assert_equal 0, record.documents.count
  end

  def test_good_job_dashboard_requires_authentication
    assert_raises(ActionController::RoutingError) { visit '/admin/good_job/web' }
  end

  def test_good_job_requires_a_completed_second_factor
    enable_otp
    login
    assert_current_path '/admin/otp/challenge'
    assert_raises(ActionController::RoutingError) { visit '/admin/good_job/web' }
    visit '/admin/otp/challenge'
    fill_in 'Authentication code', with: @user.otp_code
    click_button 'Verify and sign in'
    visit '/admin/good_job/web'
    assert_text 'GoodJob'
  end

  def test_image_preview_renders_and_vips_processes_a_variant
    record = article
    record.cover.attach(io: File.open(File.expand_path('fixtures/image.png', __dir__)), filename: 'image.png', content_type: 'image/png')
    variant = record.cover.variant(resize_to_limit: [32, 32]).processed
    require 'vips'
    image = Vips::Image.new_from_buffer(variant.download, '')
    assert_operator image.width, :<=, 32
    assert_operator image.height, :<=, 32
    login
    visit "/admin/articles/#{record.id}/edit"
    assert_selector 'img.active-storage__image'
  end

  def test_good_job_dashboard_and_wrapper_render
    login
    visit '/admin/good_job'
    assert_selector 'iframe[src="/admin/good_job/web"]'
    visit '/admin/good_job/web'
    assert_text 'GoodJob'
  end

  def test_good_job_enqueues_and_performs_against_postgresql
    record = article
    job = CompatibilityJob.perform_later(record.id)
    assert GoodJob::Job.find_by(active_job_id: job.job_id)
    GoodJob.perform_inline
    assert_equal 'Performed by GoodJob', record.reload.body_en
    assert GoodJob::Job.find_by!(active_job_id: job.job_id).finished_at
  end
end
