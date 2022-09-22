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

  def first_performance_date
    # This is actually the date of the first performance with any tickets sold
    inventory_records.
      select(&:single_performance_total_sales_record?).
      map(&:event_date).sort.first
  end

  def total_tickets_sold
    inventory_records.
      select(&:single_performance_total_sales_record?).
      sum(&:sold)
  end

  def total_tickets_available
    # n.b. the 'quantity' fields change retrospectively when you adjust in the web
    # interface. So be careful making assumptions about old shows if you increase
    # capacity during a run.
    inventory_records.
      select(&:single_performance_total_sales_record?).
      sum(&:quantity)
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
