require 'bundler/setup'
require 'rails/all'
Bundler.require(:default, :test)

%w[auth auth/otp search active_storage good_job mobility].each { |plugin| require "trestle/#{plugin}" }

class CompatibilityApp < Rails::Application
  config.root = File.expand_path('..', __dir__)
  config.load_defaults 8.1
  config.eager_load = ENV['EAGER_LOAD'] == '1'
  config.enable_reloading = false
  config.secret_key_base = 'compatibility-test-secret-' * 4
  config.active_record.encryption.primary_key = 'compatibility-otp-primary-test-key'
  config.active_record.encryption.deterministic_key = 'compatibility-otp-deterministic-test-key'
  config.active_record.encryption.key_derivation_salt = 'compatibility-otp-test-salt'
  config.hosts.clear
  config.action_controller.allow_forgery_protection = false
  config.action_dispatch.show_exceptions = :none
  config.action_mailer.delivery_method = :test
  config.active_job.queue_adapter = :good_job
  config.good_job.execution_mode = :external
  config.good_job.preserve_job_records = true
  config.active_storage.service = :test
  config.active_storage.service_configurations = {
    test: { service: 'Disk', root: File.expand_path('../../tmp/storage', __dir__) }
  }
  config.active_storage.analyzers = []
  config.active_storage.queues.purge = :default
  config.i18n.available_locales = [:en, :it]
  config.logger = Logger.new(File.expand_path('../../logs/integration-rails.log', __dir__))
  config.assets.prefix = "/assets-#{ENV.fetch('ASSET_PIPELINE', 'sprockets-rails')}"
end
