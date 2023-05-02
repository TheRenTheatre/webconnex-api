# frozen_string_literal: true

require 'test_helper'

class TestWebconnexAPITicket < Minitest::Test
  def test_all_for_form
    setup_josephine_tickets_fixtures
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/560625",
                         :response => fixture_path("v2-public-forms-560625"))
    form = WebconnexAPI::Form.find(560625)
    tickets = WebconnexAPI::Ticket.all_for_form(form)
    assert_equal 594, tickets.count
  end

  def test_tickets_instance_accessor_on_form
    setup_josephine_tickets_fixtures
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/560625",
                         :response => fixture_path("v2-public-forms-560625"))
    form = WebconnexAPI::Form.find(560625)
    assert_equal 594, form.tickets.count
  end

  def test_upcoming
    setup_josephine_tickets_fixtures
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/560625",
                         :response => fixture_path("v2-public-forms-560625"))
    form = WebconnexAPI::Form.find(560625)
    tickets = WebconnexAPI::Ticket.all_for_form(form)
    # One hour before closing matinee
    Time.stub :now, Time.new(2023, 3, 19, 14, 0, 0, "-04:00") do
      assert_equal 92, tickets.select(&:upcoming?).count
    end
  end

  def test_ticket_levels
    setup_josephine_tickets_fixtures
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/560625",
                         :response => fixture_path("v2-public-forms-560625"))
    form = WebconnexAPI::Form.find(560625)
    tickets = WebconnexAPI::Ticket.all_for_form(form)
    # One hour before closing matinee, fixtures loaded day before,
    # so no rush tickets sold yet
    Time.stub :now, Time.new(2023, 3, 19, 14, 0, 0, "-04:00") do
      assert_equal ["General Admission"],
        tickets.select(&:upcoming?).map(&:level_label).uniq
    end
    assert_equal ["General Admission", "Rush Tickets"],
      tickets.map(&:level_label).uniq.sort
  end

  def test_event_label
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/582034",
                         :response => fixture_path("v2-public-forms-582034"))
    uri = "https://api.webconnex.com/v2/public/search/tickets?product=ticketspice.com&formId=582034"
    FakeWeb.register_uri(:get, uri, :response => fixture_path("v2-public-search-tickets-formid=582034"))
    form = WebconnexAPI::Form.find(582034)
    assert_equal ["April 3rd - Dream Roles"], form.tickets.map(&:event_label).uniq
  end

  def test_inferring_event_date_for_multiple_event_type
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/582034",
                         :response => fixture_path("v2-public-forms-582034"))
    uri = "https://api.webconnex.com/v2/public/search/tickets?product=ticketspice.com&formId=582034"
    FakeWeb.register_uri(:get, uri, :response => fixture_path("v2-public-search-tickets-formid=582034"))
    form = WebconnexAPI::Form.find(582034)
    assert_equal 1, form.tickets.count
    assert_equal "April 3rd - Dream Roles", form.tickets.first.event_label
    assert_equal Time.new(2023, 4, 3, 20, 0, 0, "-04:00"), form.tickets.first.event_date
  end
end
