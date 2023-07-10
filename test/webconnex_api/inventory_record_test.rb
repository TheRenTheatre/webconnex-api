# frozen_string_literal: true

require 'test_helper'

class TestWebconnexAPIInventoryRecord < Minitest::Test
  def test_all_by_form_id_does_not_raise
    # plaintext
    # curl --http1.1 -X "GET" -is "https://api.webconnex.com/v2/public/forms/481603/inventory" -H "apiKey: ffff084aa7abee86fc0203e606faffff" -H "Accept: */*" -H "User-Agent: Ruby" -H "Host: api.webconnex.com" > test/fixtures/v2-public-forms-481603-inventory
    resp = fixture_path("v2-public-forms-481603-inventory");

    # In reality, Net::HTTP will gzip by default. FakeWeb doesn't support this. yet? lol
    # curl --http1.1 -X "GET" -is "https://api.webconnex.com/v2/public/forms/481603/inventory" -H "apiKey: ffff084aa7abee86fc0203e606faffff" -H "Accept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3" -H "Accept: */*" -H "User-Agent: Ruby" -H "Host: api.webconnex.com" > test/fixtures/v2-public-forms-481603-inventory.gzip

    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/481603/inventory", :response => resp)
    WebconnexAPI::InventoryRecord.all_by_form_id(481603)
  end

  def test_upcoming_and_past
    resp = fixture_path("v2-public-forms-481603")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/481603", :response => resp)
    resp = fixture_path("v2-public-forms-481603-inventory")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/481603/inventory", :response => resp)

    irs = WebconnexAPI::InventoryRecord.all_by_form_id(481603).select(&:single_performance_sales_record?)
    irs.each do |ir|
      refute_equal ir.upcoming?, ir.past
    end
  end

  def test_event_times_for_lenox_ave_records
    resp = fixture_path("v2-public-forms-481603")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/481603", :response => resp)
    resp = fixture_path("v2-public-forms-481603-inventory")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/481603/inventory", :response => resp)

    irs = WebconnexAPI::InventoryRecord.all_by_form_id(481603)

    single_performance_records = irs.select(&:single_performance_sales_record?)
    assert_equal 35, single_performance_records.count
    single_performance_records.each do |ir|
      assert_equal    2022,     ir.event_time.year
      assert_includes [7, 8],   ir.event_time.month
      assert_includes [20, 22], ir.event_time.hour
      assert_equal    "EDT",    ir.event_time.zone
    end

    total_records = irs.reject(&:single_performance_sales_record?)
    assert_equal 3, total_records.count
    total_records.each do |ir|
      exp = assert_raises { ir.event_time }
      assert_match(/doesn't have a time/, exp.message)
    end
  end

  def test_event_time_for_inventory_record_keys_with_date_but_no_time
    skip
  end

  def test_event_time_and_related_behavior_for_single_events
    # The inventory records for forms with eventType = "single" don't have keys,
    # which is where we'd usually find the datetime info for an individual
    # performance when starting with an Inventory Record. Instead, it falls back
    # to the Form's eventStart.
    resp = fixture_path("v2-public-forms-582221")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/582221", :response => resp)
    resp = fixture_path("v2-public-forms-582221-inventory")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/582221/inventory", :response => resp)

    irs = WebconnexAPI::InventoryRecord.all_by_form_id(582221)
    assert_equal 3, irs.count  # one overall, two ticket levels

    irs.each do |ir|
      assert ir.form.single?
      assert ir.single_performance_sales_record?
      assert ir.single_performance_sales_record_for_first_performance?
      assert (ir.single_performance_total_sales_record? ||
              ir.single_performance_ticket_level_sales_record?)

      assert_equal Time.parse("2023-04-18 20:00:00 -0400"), ir.form.event_start
      assert_equal Time.parse("2023-04-18 20:00:00 -0400"), ir.event_time
    end
  end
end
