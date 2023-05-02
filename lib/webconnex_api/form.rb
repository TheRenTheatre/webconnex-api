# frozen_string_literal: true

class WebconnexAPI::Form
  def self.all
    json = WebconnexAPI.get_request("/forms")
    body = JSON.parse(json)
    data = body["data"]
    data.map { |form|
      self.new(form)
    }
  end

  def self.find(id)
    @@cache_by_id ||= {}
    if @@cache_by_id.has_key?(id)
      @@cache_by_id[id]
    else
      json = WebconnexAPI.get_request("/forms/#{id}")
      body = JSON.parse(json)
      data = body["data"]
      @@cache_by_id[id] = self.new(data)
    end
  end

  def self.clear_cache
    @@cache_by_id = {}
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

  def total_tickets_sold
    completed_tickets.count
  end

  def total_upcoming_tickets_sold
    completed_tickets.select(&:upcoming?).count
  end

  def total_past_tickets_sold
    completed_tickets.select(&:past?).count
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

  def single?
    event_type == "single"
  end

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
          guess = guess.change(month: month, day: day)
        end
      end
    end
    guess
  end

  private def ensure_loaded
    # The List Forms API used in .all doesn't include all of the data a Form
    # can have. The big "fields" object is a reasonable one to check.
    return true if @data_from_json["fields"].present?

    myself = self.class.find(id)
    @data_from_json = myself.instance_variable_get(:@data_from_json)
  end
end
