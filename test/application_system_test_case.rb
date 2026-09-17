require "test_helper"
require "capybara/rails"
require "selenium-webdriver"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include Warden::Test::Helpers

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 1000 ] do |options|
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--no-sandbox") if ENV["CHROME_NO_SANDBOX"] == "1"
  end

  setup do
    @system_driver = Capybara.current_session.driver
    @system_driver.browser.execute_cdp("Network.setBypassServiceWorker", bypass: true)
  rescue Selenium::WebDriver::Error::NoSuchDriverError
    Capybara.current_driver = :rack_test
    raise if ENV["CI"].present?

    skip "Chrome/Chromedriver unavailable; install them to run system tests"
  end

  teardown do
    Warden.test_reset!
    @system_driver&.quit
  end

  private

  def sign_in_and_select_event(user)
    login_as(user, scope: :user)
    visit events_path
    within("form[action='#{select_event_path(events(:championship))}']") do
      click_button "Select"
    end
    assert_current_path root_path
  end
end
