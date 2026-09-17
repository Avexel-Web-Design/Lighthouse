require "application_system_test_case"

class SmokeTest < ApplicationSystemTestCase
  test "root redirects to sign in when logged out" do
    visit root_path
    # Unauthenticated users are redirected to login
    assert_current_path new_user_session_path
  end
end
