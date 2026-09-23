require "test_helper"

class GameConfigTest < ActiveSupport::TestCase
  # --- Validations ---

  test "valid game config from fixtures" do
    assert game_configs(:reefscape_2026).valid?
  end

  test "requires year" do
    config = game_configs(:reefscape_2026)
    config.year = nil
    assert_not config.valid?
    assert_includes config.errors[:year], "can't be blank"
  end

  test "requires game_name" do
    config = game_configs(:reefscape_2026)
    config.game_name = nil
    assert_not config.valid?
    assert_includes config.errors[:game_name], "can't be blank"
  end

  # --- Associations ---

  # --- Scopes ---

  test "active scope returns active configs" do
    assert_includes GameConfig.active, game_configs(:reefscape_2026)
  end

  test "active scope excludes inactive configs" do
    config = game_configs(:reefscape_2026)
    config.update!(active: false)
    assert_not_includes GameConfig.active, config
  end

  # --- Class Methods ---

  test "current returns the most recent active config by year" do
    assert_equal game_configs(:reefscape_2026), GameConfig.current
  end

  test "a newer active season can coexist with an older active config" do
    newer = GameConfig.create!(year: 2027, game_name: "Next season", active: true)
    assert_equal newer, GameConfig.current
    assert game_configs(:reefscape_2026).update(game_name: "Previous season")
  end

  test "current returns nil when no active configs" do
    GameConfig.update_all(active: false)
    assert_nil GameConfig.current
  end

  # --- Fixture data ---

  test "reefscape_2026 has correct attributes" do
    config = game_configs(:reefscape_2026)
    assert_equal "Reefscape", config.game_name
    assert_equal 2026, config.year
    assert config.active
  end
end
