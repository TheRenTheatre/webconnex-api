# frozen_string_literal: true

require 'bundler'
Bundler.require(:default, :test)

require 'webconnex_api'

require 'minitest/autorun'
require 'minitest/pride'


module WebconnexAPITestHelper
  def setup
    Object.const_set(:WEBCONNEX_API_KEY, "ffff084aa7abee86fc0203e606faffff") # made up
    FakeWeb.clean_registry
    FakeWeb.allow_net_connect = false
    super
  end

  def teardown
    Object.send(:remove_const, :WEBCONNEX_API_KEY)
    super
  end

  def fixture_path(basename)
    "test/fixtures/#{basename}".tap { |path|
      assert File.exist?(path), "Fixture missing: #{path}"
    }
  end

  # To download these fixtures in plaintext, try something like this.
  # These contain personal information, so you'll need to grab your own copy
  # for now until we can add a sanitized copy to the repo for testing.
  #
  # $ formID=560625
  # $ for startingAfter in $(seq 0 50 550); do
  # >   curl --http1.1 -X "GET" -is \
  # >   "https://api.webconnex.com/v2/public/search/tickets?product=ticketspice.com&formId=$formID&startingAfter=$startingAfter" \
  # >   -H "apiKey: $WEBCONNEX_API_KEY" -H "Accept: */*" -H "User-Agent: Ruby" -H "Host: api.webconnex.com" >
  # >   test/fixtures/v2-public-search-tickets-formid=$FormID-startingafter=$startingAfter
  # >   sleep 5
  # > done
  def setup_josephine_tickets_fixtures
    base = URI.parse("https://api.webconnex.com/v2/public/search/tickets")
    base.query = "product=ticketspice.com&formId=560625"
    base_fixture_name = "v2-public-search-tickets-formid=560625"
    (0...594).step(50) do |starting_after|
      uri = base.dup
      fixture_name = base_fixture_name.dup
      if starting_after > 0
        uri.query += "&startingAfter=#{starting_after}"
        fixture_name += "-startingafter=#{starting_after}"
      end
      FakeWeb.register_uri(:get, uri, :response => fixture_path(fixture_name))
    end
  end
end
Minitest::Test.send(:include, WebconnexAPITestHelper)
