# frozen_string_literal: true

class WebconnexAPI::Ticket
  def self.all_by_form_id(form_id)
    path = "/search/tickets"
    base_query = "product=ticketspice.com&formId=#{form_id}"
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
      self.new(ticket)
    }
  end

  def initialize(hash_from_json)
    @data_from_json = hash_from_json
  end

  def status
    @data_from_json["status"]
  end

  def completed?
    status == "completed"
  end

  def event_date
    Time.parse(@data_from_json["eventDate"])
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
