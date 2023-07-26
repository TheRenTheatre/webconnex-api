# frozen_string_literal: true

require 'net/http'
require 'json'
require 'date'
require 'time'
require 'tzinfo'
require 'active_support/core_ext/time/calculations'
require 'redis'

module WebconnexAPI
  class Error < StandardError; end

  ENDPOINT = "https://api.webconnex.com/v2/public"

  class << self
    def cache_options=(opts)
      @cache_options = opts
    end

    def cache
      return @cache if defined?(@cache)

      @cache_options ||= {}
      if @cache_options[:db].nil?
        raise "Please set a Redis DB explicitly as a best practice " +
              "to avoid test/staging/production catastrophes. Example:\n" +
              "  WebconnexAPI.cache_options = {db: 15}  \# 15 is test\n\n"
      end

      @cache = Redis.new(@cache_options)
    rescue Redis::CannotConnectError, Errno::ECONNREFUSED => e
      raise e, "Error: could not connect to Redis. Here are the options passed, " +
               "the rest are defaults: #{@cache_options.inspect}"
    end
  end

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
