require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    sign_in_as(@admin)
    select_event(events(:championship))
  end

  test "admin cannot demote self" do
    patch user_path(@admin), params: { user: { role: "scout" } }

    assert_redirected_to users_path
    assert_equal "You cannot remove your own admin access.", flash[:alert]
    assert @admin.reload.admin?
  end

  test "admin update without role change succeeds" do
    patch user_path(@admin), params: { user: { first_name: "Kept" } }

    assert_redirected_to users_path
    assert_equal "Kept", @admin.reload.first_name
  end

  test "non-admin cannot change roles" do
    scout = users(:scout_user)
    sign_in_as(scout)
    select_event(events(:championship))

    patch user_path(@admin), params: { user: { role: "scout" } }

    assert_response :redirect
    assert @admin.reload.admin?
  end

  test "unknown role values are ignored on update" do
    patch user_path(@admin), params: { user: { first_name: "Still", role: "owner" } }

    assert_redirected_to users_path
    assert @admin.reload.admin?
    assert_equal "Still", @admin.first_name
  end

  test "admin can promote another user" do
    lead = users(:lead_user)

    patch user_path(lead), params: { user: { role: "admin" } }

    assert_redirected_to users_path
    assert lead.reload.admin?
  end
end
