require "test_helper"

class UserTest < ActiveSupport::TestCase
  # --- Validations ---

  test "valid user from fixtures" do
    assert users(:admin_user).valid?
    assert users(:lead_user).valid?
    assert users(:scout_user).valid?
  end

  test "requires first_name" do
    user = users(:admin_user)
    user.first_name = nil
    assert_not user.valid?
    assert_includes user.errors[:first_name], "can't be blank"
  end

  test "requires last_name" do
    user = users(:admin_user)
    user.last_name = nil
    assert_not user.valid?
    assert_includes user.errors[:last_name], "can't be blank"
  end

  test "requires unique username" do
    duplicate = users(:admin_user).dup
    duplicate.email = "other@lighthouse.local"
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:username], "has already been taken"
  end

  test "auto-generates username from name" do
    user = User.new(first_name: "Jane", last_name: "Doe", password: "password123")
    user.valid?
    assert_equal "Jane Doe", user.username
  end

  test "explicit login fields survive creation and name changes" do
    user = User.create!(first_name: "Jane", last_name: "Doe", username: "custom-login",
                        email: "custom@example.com", password: "password123")
    user.update!(first_name: "Janet", last_name: "Smith")
    assert_equal "custom-login", user.reload.username
    assert_equal "custom@example.com", user.email
    user.update!(username: "", email: "")
    assert_equal "Janet Smith", user.username
    assert_equal "janet-smith@lighthouse.local", user.email
  end

  test "auto-generates email when blank" do
    user = User.new(first_name: "Jane", last_name: "Doe", password: "password123")
    user.valid?
    assert_equal "jane-doe@lighthouse.local", user.email
  end

  # --- Associations ---

  test "has many scouting_entries" do
    user = users(:admin_user)
    assert_respond_to user, :scouting_entries
    assert_includes user.scouting_entries, scouting_entries(:entry_qm1_254)
  end

  test "has many pit_scouting_entries" do
    user = users(:scout_user)
    assert_respond_to user, :pit_scouting_entries
    assert_includes user.pit_scouting_entries, pit_scouting_entries(:pit_254)
  end

  test "has many pick_lists" do
    user = users(:admin_user)
    assert_respond_to user, :pick_lists
    assert_includes user.pick_lists, pick_lists(:championship_picks)
  end

  test "has many simulation_results" do
    user = users(:admin_user)
    assert_respond_to user, :simulation_results
    assert_includes user.simulation_results, simulation_results(:sim_254_vs_1678)
  end

  # --- Roles ---

  test "role enum values" do
    assert_equal "admin", users(:admin_user).role
    assert_equal "analyst", users(:lead_user).role
    assert_equal "scout", users(:scout_user).role
  end

  test "admin? returns true for admin users" do
    assert users(:admin_user).admin?
    assert_not users(:scout_user).admin?
  end

  test "analyst? returns true for analyst users" do
    assert users(:lead_user).analyst?
    assert_not users(:scout_user).analyst?
  end

  test "scout? returns true for scout users" do
    assert users(:scout_user).scout?
    assert_not users(:admin_user).scout?
  end

  # --- Callbacks ---

  test "generates api_token before create" do
    user = User.new(
      password: "password123",
      first_name: "New",
      last_name: "Tokenuser"
    )
    assert_nil user.api_token
    user.save!
    assert_not_nil user.api_token
    assert_equal 64, user.api_token.length
  end

  test "does not overwrite existing api_token on create" do
    user = User.new(
      password: "password123",
      first_name: "Token",
      last_name: "Keeper",
      api_token: "preexisting_token_value"
    )
    user.save!
    assert_equal "preexisting_token_value", user.api_token
  end

  # --- Instance Methods ---

  test "full_name returns first and last name" do
    user = users(:admin_user)
    assert_equal "Admin User", user.full_name
  end

  test "full_name for lead_user" do
    assert_equal "Lead User", users(:lead_user).full_name
  end

  test "regenerate_api_token! updates api_token" do
    user = users(:admin_user)
    old_token = user.api_token
    user.regenerate_api_token!
    assert_not_equal old_token, user.api_token
    assert_equal 64, user.api_token.length
  end
end
