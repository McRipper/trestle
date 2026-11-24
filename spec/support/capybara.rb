module ChromeStorageReset
  def reset!
    super
  rescue Selenium::WebDriver::Error::InvalidArgumentError => error
    raise unless error.message.lines.first&.strip == 'invalid argument: * is not a valid URL'

    # Chrome 158 rejects the wildcard origin used by Capybara 3.40's reset.
    quit
  end
end

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
    page.driver.singleton_class.prepend(ChromeStorageReset)
  end
end
