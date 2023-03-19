# frozen_string_literal: true

require 'test_helper'

class TestWebconnexAPIForm < Minitest::Test
  # To grab a fixture in plaintext (set an ID)
  # curl --http1.1 -X "GET" -is "https://api.webconnex.com/v2/public/forms/$ID" -H "apiKey: $WEBCONNEX_API_KEY" -H "Accept: */*" -H "User-Agent: Ruby" -H "Host: api.webconnex.com" > test/fixtures/v2-public-forms-$ID
  #
  # Useful fixtures:
  # 481580 - unpublished, archived form with same name as a published one (Bullock and the Bandits)
  # 481581 - the published one
  # 481603 - one where we have inventory records fixtures as well (Lenox Ave)

  def test_find_does_not_raise
    resp = fixture_path("v2-public-forms-481581")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/481580", :response => resp)
    WebconnexAPI::Form.find(481580)
  end

  def test_published_returns_false_when_published_path_is_missing
    resp = fixture_path("v2-public-forms-481580")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/481580", :response => resp)
    form = WebconnexAPI::Form.find(481580)
    assert_nil form["publishedPath"]
    refute form.published?
  end

  def test_published_returns_true_when_published_path_is_present
    resp = fixture_path("v2-public-forms-481581")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/481581", :response => resp)
    form = WebconnexAPI::Form.find(481581)
    refute_nil form["publishedPath"]
    assert form.published?
  end

  def test_inventory_records_accessor_returns_the_same_collection_as_a_direct_call
    resp = fixture_path("v2-public-forms-481603")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/481603", :response => resp)
    form = WebconnexAPI::Form.find(481603)

    resp = fixture_path("v2-public-forms-481603-inventory")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/481603/inventory", :response => resp)
    expected = WebconnexAPI::InventoryRecord.all_by_form_id(481603)
    assert_instance_of WebconnexAPI::InventoryRecord, expected.first
    assert_equal expected, form.inventory_records
  end

  def test_inventory_records_accessor_raises_when_unpublished
    resp = fixture_path("v2-public-forms-481580")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/481580", :response => resp)
    form = WebconnexAPI::Form.find(481580)
    assert_raises do
      form.inventory_records
    end
  end

  def test_inventory_records_accessor_only_makes_api_request_once
    resp = fixture_path("v2-public-forms-481603")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/481603", :response => resp)
    form = WebconnexAPI::Form.find(481603)

    resp = fixture_path("v2-public-forms-481603-inventory")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/481603/inventory",
                         [{:response => resp}, {:exception => StandardError}])
    form.inventory_records
    form.inventory_records
  end

  def test_ticket_levels
    resp = fixture_path("v2-public-forms-481603")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/481603", :response => resp)
    form = WebconnexAPI::Form.find(481603)
    expected = {"adult" => "General Admission", "standingRoomOnly" => "Standing Room Only"}
    assert_equal expected, form.ticket_levels
  end

  def test_ticket_levels_when_fields_arent_loaded
    resp = fixture_path("v2-public-forms-all")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms", :response => resp)
    forms = WebconnexAPI::Form.all

    form = forms.find { |f| f.id == 481603 }

    resp = fixture_path("v2-public-forms-481603")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/481603", :response => resp)

    expected = {"adult" => "General Admission", "standingRoomOnly" => "Standing Room Only"}
    assert_equal expected, form.ticket_levels
  end

  def test_ticket_level_names
    resp = fixture_path("v2-public-forms-481603")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/481603", :response => resp)
    form = WebconnexAPI::Form.find(481603)
    assert_equal ["General Admission", "Standing Room Only"], form.ticket_level_names
  end

  def test_total_tickets_sold_for_josephine_with_limited_supply_on_for_default_ticket_level
    setup_josephine_tickets_fixtures
    resp = fixture_path("v2-public-forms-560625--with-limited-supply-on-for-default-ticket-level")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/560625", :response => resp)
    resp = fixture_path("v2-public-forms-560625-inventory--with-limited-supply-on-for-default-ticket-level")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/560625/inventory", :response => resp)
    form = WebconnexAPI::Form.find(560625)

    # double-check we have the right fixture
    assert_equal ["General Admission", "Rush Tickets"], form.ticket_level_names
    ga_level = form[:fields]["tickets"]["levels"].find { |l| l["attributes"]["label"] == "General Admission" }
    assert ga_level["attributes"]["limitedInventory"]
    assert_equal "124", ga_level["attributes"]["inventory"]

    assert_equal 583, form.total_tickets_sold
  end

  def test_total_tickets_sold_for_josephine_limited_supply_off_for_default_ticket_level
    setup_josephine_tickets_fixtures
    resp = fixture_path("v2-public-forms-560625--with-limited-supply-off-for-default-ticket-level")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/560625", :response => resp)
    resp = fixture_path("v2-public-forms-560625-inventory--with-limited-supply-off-for-default-ticket-level")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/560625/inventory", :response => resp)
    form = WebconnexAPI::Form.find(560625)

    # double-check we have the right fixture
    assert_equal ["General Admission", "Rush Tickets"], form.ticket_level_names
    ga_level = form[:fields]["tickets"]["levels"].find { |l| l["attributes"]["label"] == "General Admission" }
    refute ga_level["attributes"]["limitedInventory"]
    assert_empty ga_level["attributes"]["inventory"]

    assert_equal 583, form.total_tickets_sold
  end
end
