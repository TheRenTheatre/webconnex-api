# frozen_string_literal: true

class WebconnexAPI::Ticket
  def self.all_for_form(form)
    tickets_from_cache = self.all_data_from_cache_by_id_for_form(form)
    tickets_from_api   = self.all_new_ticket_data_from_api_by_id_for_form(form)

    if tickets_from_api.any?
      WebconnexAPI.cache.sadd("form:#{form.id}:ticket-ids", *tickets_from_api.keys)
    end

    (tickets_from_cache.keys | tickets_from_api.keys).map do |id|
      cache_key = "ticket:#{id}"
      merged = (tickets_from_cache[id] || {}).merge(tickets_from_api[id] || {})
      if merged != tickets_from_cache[id]
        puts "cache update: #{cache_key}"
        WebconnexAPI.cache.set(cache_key, merged.to_json)
      end
      self.new(merged, form: form)
    end
  end

  def self.all_data_from_cache_by_id_for_form(form)
    known_ids_from_cache = WebconnexAPI.cache.smembers("form:#{form.id}:ticket-ids")
    return {} if known_ids_from_cache.none?
    cache_keys = known_ids_from_cache.map { |ticket_id| "ticket:#{ticket_id}" }
    WebconnexAPI.cache.mapped_mget(*cache_keys).
      transform_keys { |cache_key| cache_key[7..-1] }.
      transform_values { |json| JSON.parse(json) }
  end

  def self.all_new_ticket_data_from_api_by_id_for_form(form)
    cache_last_updated = WebconnexAPI.cache.get("api-last-checked-at:tickets-for-form-#{form.id}")

    path = "/search/tickets"
    base_query = "product=ticketspice.com&formId=#{form.id}"
    base_query += "&dateUpdatedAfter=#{cache_last_updated}" if !cache_last_updated.nil?

    tickets_from_api = {}
    time_check_started = Time.now
    json = WebconnexAPI.get_request(path, query: base_query)
    body = JSON.parse(json)
    body["data"].each { |t| tickets_from_api[t["id"]] = t }
    while body["hasMore"] && body["totalResults"] > 0
      query = base_query + "&startingAfter=#{body['startingAfter']}"
      json = WebconnexAPI.get_request(path, query: query)
      body = JSON.parse(json)
      body["data"].each { |t| tickets_from_api[t["id"]] = t }
    end

    WebconnexAPI.cache.set("api-last-checked-at:tickets-for-form-#{form.id}", time_check_started.utc.xmlschema)

    tickets_from_api
  end

  def self.clear_cache
    sets_of_forms_fkeys = WebconnexAPI.cache.keys("form:*:ticket-ids")
    WebconnexAPI.cache.del(*sets_of_forms_fkeys)

    json_ticket_keys = WebconnexAPI.cache.keys("ticket:*")
    WebconnexAPI.cache.del(*json_ticket_keys)

    timestamps_of_searches = WebconnexAPI.cache.keys("api-last-checked-at:tickets-for-form-*")
    WebconnexAPI.cache.del(*timestamps_of_searches)
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

  # This is present for tickets to forms with the 'multiple' event_type.
  def event_label
    @data_from_json["eventLabel"]
  end

  def upcoming?
    event_date > Time.now
  end

  def past?
    event_date <= Time.now
  end

  # This is the human-readable version, like "General Admission"
  def level_label
    @data_from_json["levelLabel"]
  end

  # This is the computery version, like "adult"
  def level_key
    @data_from_json["levelKey"]
  end

  def amount_cents
    (@data_from_json["amount"].to_f * 100).to_i
  end

  def fee_cents
    (@data_from_json["fee"].to_f * 100).to_i
  end

  def total_cents
    (@data_from_json["total"].to_f * 100).to_i
  end
end
