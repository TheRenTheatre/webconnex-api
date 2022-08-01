class WebconnexAPI::InventoryRecord < OpenStruct
  def self.all_by_form_id(form_id)
    json = WebconnexAPI.get_request("/forms/#{form_id}/inventory")
    JSON.parse(json, object_class: self).data.reject { |ir|
      ir.name == "tickets"
    }
  end

  def event_time
    # TODO: These fields don't have a TZ on them. Works great when this machine
    # is in the event TZ... =D
    # We could allow the user to configure this class with a TZ name to assume,
    # like "America/New_York"
    @event_time ||= Time.strptime(key, "%Y-%m-%d %H:%M")
  end
end
