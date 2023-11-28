# frozen_string_literal: true

require 'test_helper'

class TestWebconnexAPIForm < Minitest::Test
  # To grab a fixture in plaintext:
  # FormID=481580; curl --http1.1 -X "GET" -is "https://api.webconnex.com/v2/public/forms/$FormID" -H "apiKey: $WEBCONNEX_API_KEY" \
  # -H "Accept: */*" -H "User-Agent: Ruby" -H "Host: api.webconnex.com" > test/fixtures/v2-public-forms-$FormID
  #
  # Useful fixtures:
  # 481580 - unpublished, archived form with same name as a published one (Bullock and the Bandits)
  # 481581 - the published one
  # 481603 - one where we have inventory records fixtures as well (Lenox Ave)
  # 582034 - MM Cabaret Superstar 2023 - 'multiple' event-type with no structured event date data

  def register_list_forms_responses
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms?product=ticketspice.com",
                         :response => fixture_path("v2-public-forms-all"))
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms?product=ticketspice.com&startingAfter=50",
                         :response => fixture_path("v2-public-forms-all-startingafter=50"))
  end

  def test_find_does_not_raise
    resp = fixture_path("v2-public-forms-481581")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/481581", :response => resp)
    WebconnexAPI::Form.find(481581)
  end

  def test_all_can_return_more_than_a_page_of_results
    register_list_forms_responses
    assert_equal 61, WebconnexAPI::Form.all.count
  end

  def test_published_returns_false_when_published_path_is_missing
    resp = fixture_path("v2-public-forms-481580")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/481580", :response => resp)
    form = WebconnexAPI::Form.find(481580)
    assert_nil form.published_path
    refute form.published?
  end

  def test_published_returns_true_when_published_path_is_present
    resp = fixture_path("v2-public-forms-481581")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/481581", :response => resp)
    form = WebconnexAPI::Form.find(481581)
    refute_nil form.published_path
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
    register_list_forms_responses
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
    ga_level = form.fields["tickets"]["levels"].find { |l| l["attributes"]["label"] == "General Admission" }
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
    ga_level = form.fields["tickets"]["levels"].find { |l| l["attributes"]["label"] == "General Admission" }
    refute ga_level["attributes"]["limitedInventory"]
    assert_empty ga_level["attributes"]["inventory"]

    assert_equal 583, form.total_tickets_sold
  end

  def test_event_type_recurring
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/560625",
                         :response => fixture_path("v2-public-forms-560625"))
    form = WebconnexAPI::Form.find(560625)
    assert_equal "recurring", form.event_type
  end

  def test_event_type_single
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/582221",
                         :response => fixture_path("v2-public-forms-582221"))
    form = WebconnexAPI::Form.find(582221)
    assert_equal "single", form.event_type
  end

  def test_event_type_on_object_from_collection
    # This is one of the fields that isn't returned in the List Forms API,
    # so this ensures that it's loaded when needed.
    register_list_forms_responses
    forms = WebconnexAPI::Form.all

    lenoxes = forms.select { |f| f.published? && f.name == "Lenox Ave" }
    assert_equal 1, lenoxes.count
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/481603",
                         :response => fixture_path("v2-public-forms-481603"))
    assert_equal "recurring", lenoxes.first.event_type

    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/432935",
                         :response => fixture_path("v2-public-forms-432935"))
    concert = forms.find { |f| f.id == 432935 }
    assert_equal "Stephen Pugh in Concert", concert.name
    assert_equal "single", concert.event_type
  end

  def test_loading_builds_similar_object
    register_list_forms_responses
    forms = WebconnexAPI::Form.all
    lenox_from_list_forms_api = forms.find { |f| f.id == 481603 }
    assert_equal "Lenox Ave", lenox_from_list_forms_api.name

    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/481603",
                              :response => fixture_path("v2-public-forms-481603"))
    lenox_from_view_form_api = WebconnexAPI::Form.find(481603, reload: true)
    assert_equal "Lenox Ave", lenox_from_view_form_api.name

    refute_equal lenox_from_view_form_api.instance_variable_get(:@data_from_json),
                 lenox_from_list_forms_api.instance_variable_get(:@data_from_json)

    # cause this one to load
    lenox_from_list_forms_api.fields
    assert_equal lenox_from_view_form_api.instance_variable_get(:@data_from_json),
                 lenox_from_list_forms_api.instance_variable_get(:@data_from_json)
  end

  def test_event_list_for_multiple_event_type
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/582034",
                         :response => fixture_path("v2-public-forms-582034"))
    form = WebconnexAPI::Form.find(582034)

    expected = {"event1"             => "April 3rd - Dream Roles",
                "event2"             => "April 10th - Funny Girl (Comedic)",
                "event3"             => 'April 17th - "Go To" Songs',
                "april24th11Oclock"  => "April 24th - 11 O’Clock Numbers",
                "may1stGrandeFinale" => "May 1st - Grande Finale"}
    assert_equal expected, form.event_list

    expected = [
      "April 3rd - Dream Roles", "April 10th - Funny Girl (Comedic)",
      'April 17th - "Go To" Songs', "April 24th - 11 O’Clock Numbers",
      "May 1st - Grande Finale"
    ]
    assert_equal expected, form.event_list_names
  end

  def test_guessed_event_date_for_event_list_name
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/582034",
                         :response => fixture_path("v2-public-forms-582034"))
    form = WebconnexAPI::Form.find(582034)

    expected_guesses = {
      "April 3rd - Dream Roles"           => Time.new(2023, 4, 3,  20, 0, 0, "-04:00"),
      "April 10th - Funny Girl (Comedic)" => Time.new(2023, 4, 10, 20, 0, 0, "-04:00"),
      'April 17th - "Go To" Songs'        => Time.new(2023, 4, 17, 20, 0, 0, "-04:00"),
      "April 24th - 11 O’Clock Numbers"   => Time.new(2023, 4, 24, 20, 0, 0, "-04:00"),
      "May 1st - Grande Finale"           => Time.new(2023, 5, 1,  20, 0, 0, "-04:00")
    }
    expected_guesses.each do |event_label, expected|
      assert_equal expected, form.guessed_event_date_for_event_list_name(event_label)
    end
  end

  def test_event_start_converts_to_event_time_zone_correctly
    # The responses I get from the API are "xmlschema" format, and explicitly UTC.
    # We'd like to return these in the local zone of the event.
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/582034",
                         :response => fixture_path("v2-public-forms-582034"))
    form = WebconnexAPI::Form.find(582034)

    assert_equal "2023-04-04T00:00:00Z", form.instance_variable_get(:@data_from_json)["eventStart"]
    assert_equal "2023-04-03 20:00:00 -0400", form.event_start.to_s
  end

  def test_any_performances_during_year
    setup_josephine_tickets_fixtures
    resp = fixture_path("v2-public-forms-560625--with-limited-supply-on-for-default-ticket-level")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/560625", :response => resp)

    form = WebconnexAPI::Form.find(560625)

    refute form.any_performances_during_year?(2022)
    assert form.any_performances_during_year?(2023)
    refute form.any_performances_during_year?(2024)
  end
end
