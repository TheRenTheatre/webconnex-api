# frozen_string_literal: true

require 'test_helper'

class TestWebconnexAPI < Minitest::Test
  def test_module_exists
    # just a test... test
    assert defined?(WebconnexAPI)
  end

  def test_version
    refute_nil WebconnexAPI::VERSION
  end
end
