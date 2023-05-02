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
    json = WebconnexAPI.get_request("/forms/#{id}")
    body = JSON.parse(json)
    data = body["data"]
    self.new(data)
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

  def event_start
    if single?
      ensure_loaded
      tz = TZInfo::Timezone.get(@data_from_json["timeZone"])
      tz.to_local(Time.xmlschema(@data_from_json["eventStart"]))
    elsif @data_from_json.has_key?("eventStart")
      raise "This form has an eventStart but its event_type is #{event_type}, which isn't handled"
    else
      raise "This form does not have an eventStart"
    end
  end

  private def ensure_loaded
    # The List Forms API used in .all doesn't include all of the data a Form
    # can have. The big "fields" object is a reasonable one to check.
    if @data_from_json["fields"].nil?
      myself = self.class.find(id)
      @data_from_json = myself.instance_variable_get(:@data_from_json)
    end
  end
end
