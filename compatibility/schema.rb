require_relative 'app/config/environment'

unless ActiveRecord::Base.connection_db_config.database == 'trestle_rails81_test'
  abort 'This harness requires its isolated trestle_rails81_test database.'
end

ActiveRecord::Schema.define do
  unless table_exists?(:administrators)
    create_table :administrators do |t|
      t.string :email
      t.string :password_digest
      t.string :first_name
      t.string :last_name
      t.string :remember_token
      t.datetime :remember_token_expires_at
      t.text :otp_secret_key
      t.boolean :otp_module, default: false, null: false
      t.timestamps
    end
  end
  unless column_exists?(:administrators, :otp_last_used_at)
    change_column :administrators, :otp_secret_key, :text
    add_column :administrators, :otp_last_used_at, :bigint
    add_column :administrators, :otp_recovery_codes_digest, :text, default: '[]', null: false
    add_column :administrators, :otp_session_token, :string
    add_column :administrators, :otp_failed_attempts, :integer, default: 0, null: false
    add_column :administrators, :otp_locked_until, :datetime
  end
  unless table_exists?(:articles)
    create_table :articles do |t|
      t.jsonb :title, default: {}
      t.jsonb :body, default: {}
      t.jsonb :published, default: {}
      t.timestamps
    end
  end
end

unless ActiveRecord::Base.connection.table_exists?(:active_storage_blobs)
  load File.join(Gem::Specification.find_by_name('activestorage').full_gem_path,
                 'db/migrate/20170806125915_create_active_storage_tables.rb')
  CreateActiveStorageTables.migrate(:up)
end

unless ActiveRecord::Base.connection.table_exists?(:good_jobs)
  template = File.join(Gem::Specification.find_by_name('good_job').full_gem_path,
                       'lib/generators/good_job/templates/install/migrations/create_good_jobs.rb.erb')
  eval ERB.new(File.read(template)).result_with_hash(migration_version: '[8.1]'), TOPLEVEL_BINDING, template
  CreateGoodJobs.migrate(:up)
end
