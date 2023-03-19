# frozen_string_literal: true

class WebconnexAPI::Form < OpenStruct
  def self.all
    json = WebconnexAPI.get_request("/forms")
    JSON.parse(json, object_class: self).data
  end

  def self.find(id)
    json = WebconnexAPI.get_request("/forms/#{id}")
    JSON.parse(json, object_class: self).data
  end

  def inventory_records
    # API responds with a 400 if you do this:
    # "inventory not generated till form is published"
    raise "Cannot retrieve inventory records for an unpublished form" if !published?

    @inventory_records ||= WebconnexAPI::InventoryRecord.all_by_form_id(id)
  end


  private def inventory_records_for_sales_stats
    inventory_records.
      select(&:single_performance_total_sales_record?).
      reject(&:none_sold?)
  end

  def first_performance_date
    # This is actually the date of the first performance with any tickets sold
    inventory_records_for_sales_stats.map(&:event_date).sort.first
  end

  def total_tickets_sold
    inventory_records_for_sales_stats.sum(&:sold)
  end

  def total_upcoming_tickets_sold
    inventory_records_for_sales_stats.select(&:upcoming?).sum(&:sold)
  end

  def total_past_tickets_sold
    inventory_records_for_sales_stats.select(&:past?).sum(&:sold)
  end

  def total_tickets_available
    # n.b. the 'quantity' fields change retrospectively when you adjust in the web
    # interface. So be careful making assumptions about old shows if you increase
    # capacity during a run.
    inventory_records_for_sales_stats.sum(&:quantity)
  end

  def total_upcoming_tickets_available
    inventory_records_for_sales_stats.select(&:upcoming?).sum(&:quantity)
  end

  def total_past_tickets_available
    inventory_records_for_sales_stats.select(&:past?).sum(&:quantity)
  end

  def ticket_levels
    # TODO temporary (lol). We obviously need some sort of loading mechanism
    # here. The List Forms API used in .all doesn't include all of the data a
    # Form can have.
    if self[:fields].nil?
      myself = self.class.find(id)
      self[:fields] = myself.fields
    end

    self[:fields]["tickets"]["levels"].reduce({}) { |h, level|
      h.merge(level[:key] => level["attributes"]["label"])
    }
  end

  def ticket_level_names
    ticket_levels.values
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

  def published?
    !publishedPath.nil?
  end
end
