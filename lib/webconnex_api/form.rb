class WebconnexAPI::Form < OpenStruct
  def self.all
    json = WebconnexAPI.get_request("/forms")
    JSON.parse(json, object_class: self).data
  end

  def inventory_records
    WebconnexAPI::InventoryRecord.all_by_form_id(id)
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
end
