require "application_system_test_case"

class ScoutingSmokeTest < ApplicationSystemTestCase
  test "scout submits a live match entry" do
    sign_in_and_select_event(users(:scout_user))
    visit new_scouting_entry_path
    select "Q3", from: "Match"
    select "254 - The Cheesy Poofs", from: "Team"
    find("[aria-label='Score made fuel in autonomous']").click
    assert_selector "[data-scouting-target='autonMade']", text: "1", exact_text: true

    uuid = find("#scouting_entry_client_uuid", visible: false).value
    find("#scouting-form [type='submit']").click
    assert_selector "h1", text: "Scouting Entry"

    entry = ScoutingEntry.find_by!(client_uuid: uuid)
    assert_equal users(:scout_user), entry.user
    assert_equal matches(:qm3), entry.match
    assert_equal 1, entry.data["auton_fuel_made"]
  end

  test "analyst imports a decoded QR payload without a camera" do
    sign_in_and_select_event(users(:lead_user))
    visit scanner_qr_imports_path
    assert_selector "h1", text: "QR Scanner"

    payload = {
      v: 1, u: "system-qr-smoke", mk: matches(:qm3).tba_key,
      tn: 254, ek: events(:championship).tba_key, afm: 3,
      ts: Time.current.iso8601
    }.to_json
    result = page.evaluate_async_script(<<~JS, payload)
      const payload = arguments[0];
      const done = arguments[arguments.length - 1];
      import("controllers/application").then(({ application }) => {
        const element = document.querySelector('[data-controller="qr-scanner"]');
        const controller = application.getControllerForElementAndIdentifier(element, "qr-scanner");
        if (!controller) throw new Error("QR controller not connected");
        return controller.handleScan(payload);
      }).then(() => done("ok")).catch(error => done(error.message));
    JS
    assert_equal "ok", result
    within("[data-qr-scanner-target='list']") do
      assert_text "Team 254"
      assert_link "View"
    end
    entry = ScoutingEntry.find_by!(client_uuid: "system-qr-smoke")
    assert_equal 3, entry.data["auton_fuel_made"]
    assert_equal events(:championship), entry.event
  end

  test "admin renders the pick list with ranked teams" do
    sign_in_and_select_event(users(:admin_user))
    visit pick_list_path(pick_lists(:championship_picks))

    assert_selector "h1", text: "Championship Pick List"
    assert_selector "[data-sortable-target='item']", count: 4
    assert_selector "[role='listitem'][data-team-number='254']", text: "The Cheesy Poofs"
    assert_selector "select[aria-label='Sort pick list']"
  end
end
