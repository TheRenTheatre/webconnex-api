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
    "test/fixtures/#{basename}"
  end
end
Minitest::Test.send(:include, WebconnexAPITestHelper)
