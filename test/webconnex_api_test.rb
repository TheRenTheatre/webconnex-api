# frozen_string_literal: true

require 'test_helper'

class TestWebconnexAPI < Test::Unit::TestCase
  def test_module_exists
    # just a test... test
    assert defined?(WebconnexAPI)
  end

  def test_version
    refute WebconnexAPI::VERSION.nil?
  end
end
