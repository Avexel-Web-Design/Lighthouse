# frozen_string_literal: true

require "test_helper"

# Pattern for per-policy tests: each policy authorizes its actions with the
# role hierarchy scout < analyst < admin (see ApplicationPolicy). Copy this
# file per policy, rename the class, and adjust the action matrix to match
# the policy's methods. Fixture records: see test/fixtures.
#
# Covered policies (14 with record scope):
#   DataConflictPolicy, EventPolicy, FrcTeamPolicy, PickListPolicy,
#   PitScoutingEntryPolicy, ScoutingAssignmentPolicy, ScoutingEntryPolicy,
#   SimulationResultPolicy, UserPolicy + symbol-record policies:
#   DashboardPolicy, ExportPolicy, MatchSimulatorPolicy, PredictionPolicy,
#   QrImportPolicy, TeamComparisonPolicy, WebPushSubscriptionPolicy
class ScoutingEntryPolicyTest < ActiveSupport::TestCase
  setup do
    @record = scouting_entries(:entry_qm1_254)
    @admin = users(:admin_user)
    @analyst = users(:lead_user)
    @scout = users(:scout_user)
  end

  test "admin can index, show, create, update, destroy and sync" do
    policy = ScoutingEntryPolicy.new(@admin, @record)

    assert policy.index?
    assert policy.show?
    assert policy.create?
    assert policy.update?
    assert policy.destroy?
    assert policy.sync?
    assert policy.approve?
  end

  test "analyst can manage entries but not admin approve" do
    policy = ScoutingEntryPolicy.new(@analyst, @record)

    assert policy.index?
    assert policy.show?
    assert policy.create?
    assert policy.update?
    assert policy.destroy?
    assert policy.sync?
    assert_not policy.approve?
  end

  test "scout can create and sync own entries but not destroy" do
    own = scouting_entries(:entry_qm2_254) # owned by scout_user
    policy = ScoutingEntryPolicy.new(@scout, own)

    assert policy.index?
    assert policy.show?
    assert policy.create?
    assert policy.update? # owner
    assert policy.sync?
    assert_not policy.destroy?
    assert_not policy.approve?
  end

  test "scout cannot update another scout's entry" do
    policy = ScoutingEntryPolicy.new(@scout, @record)

    assert_not policy.update?
  end

  test "scope resolves all records for any role" do
    admin_scope = ScoutingEntryPolicy::Scope.new(@admin, ScoutingEntry)
    assert_equal ScoutingEntry.all.to_a, admin_scope.resolve.to_a
  end

  # --- Default-deny regression guards (ApplicationPolicy) ---

  test "policies are deny-by-default for actions the policy does not define" do
    # ApplicationPolicy defaults: e.g. PitScoutingEntry-style policies and
    # undefined actions return false rather than allowing implicitly.
    policy = ApplicationPolicy.new(@scout, @record)

    assert_not policy.index?
    assert_not policy.show?
    assert_not policy.create?
    assert_not policy.update?
    assert_not policy.destroy?
  end
end
