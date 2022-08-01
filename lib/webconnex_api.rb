require 'net/http'
require 'json'
require 'date'
require 'time'

module WebconnexAPI
  ENDPOINT = "https://api.webconnex.com/v2/public"

  def self.get_request(path)
    uri = URI(WebconnexAPI::ENDPOINT + path)
    request = Net::HTTP::Get.new(uri)
    request["apiKey"] = WEBCONNEX_API_KEY

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http|
      http.request(request)
    }
    response.body
  end
end

require 'webconnex_api/form'
require 'webconnex_api/inventory_record'
