# frozen_string_literal: true

require 'net/http'
require 'json'
require 'date'
require 'time'
require 'tzinfo'

module WebconnexAPI
  class Error < StandardError; end

  ENDPOINT = "https://api.webconnex.com/v2/public"

  def self.get_request(path, query: nil)
    uri = URI(WebconnexAPI::ENDPOINT + path)
    uri.query = query
    request = Net::HTTP::Get.new(uri)
    request["apiKey"] = WEBCONNEX_API_KEY

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http|
      http.request(request)
    }
    if !response.is_a?(Net::HTTPSuccess)
      raise Error, "The API responded with a #{response.code}: #{response.body}"
    end
    response.body
  end
end

require_relative 'webconnex_api/form'
require_relative 'webconnex_api/inventory_record'
require_relative 'webconnex_api/ticket'
require_relative 'webconnex_api/version'
