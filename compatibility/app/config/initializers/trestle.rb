Trestle.configure do |config|
  config.auth.user_class = -> { Administrator }
  config.auth.user_admin = -> { :administrators }

  config.tinymce.default.configure do |editor|
    editor.license_key = 'gpl'
  end

  config.tinymce.summary.configure do |editor|
    editor.license_key = 'gpl'
    editor.plugins = [:link]
    editor.toolbar = 'link'
    editor.menubar = false
  end
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
