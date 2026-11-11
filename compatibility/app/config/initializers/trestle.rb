Trestle.configure do |config|
  config.auth.user_class = -> { Administrator }
  config.auth.user_admin = -> { :administrators }
end

Mobility.configure do
  plugins do
    backend :jsonb
    active_record
    reader
    writer
    locale_accessors [:en, :it]
  end
end
