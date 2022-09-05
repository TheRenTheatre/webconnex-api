# frozen_string_literal: true

require 'bundler'
Bundler.require(:default, :test)

require 'webconnex_api'

class Test::Unit::TestCase
  alias setup_without_webconnex_api setup
  def setup
    Object.const_set(:WEBCONNEX_API_KEY, "ffff084aa7abee86fc0203e606faffff") # made up
    FakeWeb.allow_net_connect = false
  end

  alias teardown_without_webconnex_api teardown
  def teardown
    Object.send(:remove_const, :WEBCONNEX_API_KEY)
  end
end

module WebconnexAPITestHelper
  def fixture_path(basename)
    "test/fixtures/#{basename}"
  end
end
Test::Unit::TestCase.send(:include, WebconnexAPITestHelper)
