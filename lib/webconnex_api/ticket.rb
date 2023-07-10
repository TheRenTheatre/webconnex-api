# frozen_string_literal: true

class WebconnexAPI::Ticket
  def self.all_for_form(form)
    path = "/search/tickets"
    base_query = "product=ticketspice.com&formId=#{form.id}"
    json = WebconnexAPI.get_request(path, query: base_query)
    body = JSON.parse(json)
    data = body["data"]
    requests = 1
    while body["hasMore"]
      query = base_query + "&startingAfter=#{body['startingAfter']}"
      json = WebconnexAPI.get_request(path, query: query)
      body = JSON.parse(json)
      data += body["data"]
      requests += 1
      # sleep 0.1 * requests
    end
    data.map { |ticket|
      self.new(ticket, form: form)
    }
  end

  def initialize(hash_from_json, form: nil)
    @data_from_json = hash_from_json
    @form = form
  end

  attr_reader :form

  def status
    @data_from_json["status"]
  end

  def completed?
    status == "completed"
  end

  # This is an ISO 8601-style datetime that seems to always come back in UTC
  # (e.g. "2023-06-28T23:30:00Z"). We'll wrap it in a Time-like object in the
  # time zone of the event.
  def event_date
    # TODO: when a recurring form has no time slots set up, this will be midnight UTC.
    # try to override it with the event's start time?

    if @data_from_json.has_key?("eventDate")
      form.time_zone.to_local(Time.xmlschema(@data_from_json["eventDate"]))
    elsif form.single?
      form.event_start
    elsif form.multiple?
      form.guessed_event_date_for_event_list_name(event_label)
    else
      raise "This ticket doesn't have an eventDate and we don't know where else to find that"
    end
  end

  def event_label
    @data_from_json["eventLabel"]
  end

  def upcoming?
    event_date > Time.now
  end

  def past?
    event_date <= Time.now
  end

  def level_label
    @data_from_json["levelLabel"]
  end
end
