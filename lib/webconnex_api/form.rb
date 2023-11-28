# frozen_string_literal: true

class WebconnexAPI::Form
  def self.all
    forms_from_cache = self.all_data_from_cache_by_id
    forms_from_api   = self.all_new_data_from_list_api_by_id

    if forms_from_api.any?
      WebconnexAPI.cache.sadd("form-ids", *forms_from_api.keys)
    end

    (forms_from_cache.keys | forms_from_api.keys).map do |id|
      cache_key = "form:#{id}"
      merged = (forms_from_cache[id] || {}).merge(forms_from_api[id] || {})
      if merged != forms_from_cache[id]
        puts "cache update: #{cache_key}"
        WebconnexAPI.cache.set(cache_key, merged.to_json)
      end
      self.new(merged)
    end
  end

  def self.all_data_from_cache_by_id
    known_ids_from_cache = WebconnexAPI.cache.smembers("form-ids")
    return {} if known_ids_from_cache.none?
    cache_keys = known_ids_from_cache.map { |form_id| "form:#{form_id}" }
    json_by_cache_key = WebconnexAPI.cache.mapped_mget(*cache_keys)
    missing_keys = json_by_cache_key.select { |key, json| json.nil? }.keys
    if missing_keys.any?
      self.clear_cache
      $stderr.puts <<-ERR
                     Cache inconsistency: #{missing_keys.count} forms were marked as cached but are not
                       actually present, e.g. cache keys like #{missing_keys[0..2].map(&:inspect).join(', ')} are missing.
                       Better start over; we've just called `#{self}.clear_cache` and are now exiting.
                   ERR
      exit 1
    end
    json_by_cache_key.
      transform_keys { |cache_key| cache_key[5..-1] }.
      transform_values { |json| JSON.parse(json) }
  end

  def self.all_new_data_from_list_api_by_id
    cache_last_updated = WebconnexAPI.cache.get("api-last-checked-at:list-forms")

    path       = "/forms"
    base_query = "product=ticketspice.com"
    base_query += "&dateUpdatedAfter=#{cache_last_updated}" if !cache_last_updated.nil?

    forms_from_api = {}
    time_check_started = Time.now
    json = WebconnexAPI.get_request(path, query: base_query)
    body = JSON.parse(json)
    body["data"].each { |f| forms_from_api[f["id"]] = f }
    while body["hasMore"] && body["totalResults"] > 0
      query = base_query + "&startingAfter=#{body['startingAfter']}"
      json = WebconnexAPI.get_request(path, query: query)
      body = JSON.parse(json)
      body["data"].each { |f| forms_from_api[f["id"]] = f }
    end

    WebconnexAPI.cache.set("api-last-checked-at:list-forms", time_check_started.utc.xmlschema)

    forms_from_api
  end

  def self.find(id, options = {})
    # TODO: restore in-memory cache so there's only one Ruby object floating around for each ID?
    cache_key = "form:#{id}"
    if !options[:reload] && json = WebconnexAPI.cache.get(cache_key)
      data = JSON.parse(json)
    else
      json = WebconnexAPI.get_request("/forms/#{id}")
      body = JSON.parse(json)
      data = body["data"]
      WebconnexAPI.cache.set(cache_key, data.to_json)
      WebconnexAPI.cache.sadd("form-ids", id)
      puts "cache update: #{cache_key}"
    end
    self.new(data)
  end

  def self.clear_cache
    form_ids = WebconnexAPI.cache.smembers("form-ids")
    WebconnexAPI.cache.del("form-ids")
    cache_keys = form_ids.map { |id| "form:#{id}" }
    WebconnexAPI.cache.del(*cache_keys)
    WebconnexAPI.cache.del("api-last-checked-at:list-forms")
  end

  def initialize(hash_from_json)
    @data_from_json = hash_from_json
  end

  def inspect
    %Q(#<WebconnexAPI::Form id=#{id.inspect}, name=#{name.inspect}, event_type=#{event_type.inspect}>)
  end

  def id
    @data_from_json["id"]
  end

  def name
    @data_from_json["name"]
  end

  def inventory_records
    # API responds with a 400 if you do this:
    # "inventory not generated till form is published"
    raise "Cannot retrieve inventory records for an unpublished form" if !published?

    @inventory_records ||= WebconnexAPI::InventoryRecord.all_by_form_id(id)
  end

  def tickets
    @tickets ||= WebconnexAPI::Ticket.all_for_form(self)
  end

  private def inventory_records_for_sales_stats
    inventory_records.
      select(&:single_performance_total_sales_record?).
      reject(&:none_sold?)
  end

  private def completed_tickets
    @completed_tickets ||= tickets.select(&:completed?)
  end

  def tickets_for_event_date(event_date)
    completed_tickets.select { |t|
      t.event_date == event_date
    }
  end

  def first_performance_date
    # This is actually the date of the first performance with any tickets sold
    completed_tickets.map(&:event_date).sort.first
  end

  def last_performance_date
    # This is actually the date of the last performance with any tickets sold
    completed_tickets.map(&:event_date).sort.last
  end

  def any_performances_during_year?(year)
    (first_performance_date.year..last_performance_date.year).include?(year.to_i)
  end

  def total_tickets_sold
    completed_tickets.count
  end

  def total_upcoming_tickets_sold
    completed_tickets.select(&:upcoming?).count
  end

  def total_past_tickets_sold
    completed_tickets.select(&:past?).count
  end

  def total_revenue_cents
    completed_tickets.sum(&:amount_cents)
  end

  def upcoming_revenue_cents
    completed_tickets.select(&:upcoming?).sum(&:amount_cents)
  end

  def past_revenue_cents
    completed_tickets.select(&:past?).sum(&:amount_cents)
  end

  # n.b. the 'quantity' fields change retrospectively when you adjust in the web
  # interface. So be careful making assumptions about old shows if you increase
  # capacity during a run.
  def total_tickets_available
    if single?
      inventory_records.find(&:overall_capacity_record?).quantity
    else
      inventory_records_for_sales_stats.sum(&:quantity)
    end
  end

  def total_upcoming_tickets_available
    now = Time.now
    if single? && event_start <= now
      0
    elsif single? && event_start > now
      inventory_records.find(&:overall_capacity_record?).quantity
    else
      inventory_records_for_sales_stats.select(&:upcoming?).sum(&:quantity)
    end
  end

  def total_past_tickets_available
    now = Time.now
    if single? && event_start > now
      0
    elsif single? && event_start <= now
      inventory_records.find(&:overall_capacity_record?).quantity
    else
      inventory_records_for_sales_stats.select(&:past?).sum(&:quantity)
    end
  end

  def ticket_levels
    fields["tickets"]["levels"].reduce({}) { |h, level|
      h.merge(level["key"] => level["attributes"]["label"])
    }
  end

  def ticket_level_names
    ticket_levels.values
  end

  def status
    @data_from_json["status"]
  end

  def archived?
    status == "archived"
  end

  def open?
    status == "open"
  end

  def closed?
    status == "closed"
  end

  def published_path
    @data_from_json["publishedPath"]
  end

  def published?
    !published_path.nil?
  end

  def event_type
    fields["tickets"]["eventType"]
  end

  # This is sometimes called "Standard" in the web UI
  def single?
    event_type == "single"
  end

  # I believe this is the "multiple events" one. There's also a
  # "multiple days" event type I haven't encountered yet.
  def multiple?
    event_type == "multiple"
  end

  def recurring?
    event_type == "recurring"
  end

  def fields
    ensure_loaded
    @data_from_json["fields"]
  end

  def time_zone
    ensure_loaded
    return nil if !time_zone?
    TZInfo::Timezone.get(@data_from_json["timeZone"])
  end

  def time_zone?
    ensure_loaded
    @data_from_json.has_key?("timeZone")
  end

  def event_start
    ensure_loaded
    if @data_from_json.has_key?("eventStart")
      time_zone.to_local(Time.xmlschema(@data_from_json["eventStart"]))
    else
      nil
    end
  end

  def event_start?
    ensure_loaded
    @data_from_json.has_key?("eventStart")
  end

  def event_list
    fields["tickets"]["events"]["options"].reduce({}) { |list, option|
      list.update(option["key"] => option["attributes"]["label"])
    }
  end

  def event_list_names
    event_list.values
  end

  def guessed_event_date_for_event_list_name(event_list_name)
    guess = event_start
    Date::MONTHNAMES.each_with_index do |month_name, month|
      next if month == 0
      (1..31).each do |day|
        if event_list_name.include?("#{month_name} #{ActiveSupport::Inflector.ordinalize(day)}")
          # Something about our Time object receiving #change makes it return a new
          # object with the machine's TZ slapped on it intead of the receiver's TZ,
          # therefore changing other fields inadvertently. This dance fixes it.
          # TODO: figure out why this is happening, DRY up the pattern
          in_machine_zone = guess.change(month: month, day: day)
          guess = time_zone.to_local(time_zone.local_to_utc(in_machine_zone))
        end
      end
    end
    guess
  end

  private def ensure_loaded
    # The List Forms API used in .all doesn't include all of the data a Form
    # can have. The big "fields" object is a reasonable one to check.
    return true if @data_from_json["fields"].present?

    myself = self.class.find(id, reload: true)
    @data_from_json = myself.instance_variable_get(:@data_from_json)
  end
end
