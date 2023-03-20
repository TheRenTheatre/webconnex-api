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

  def test_it_raises_our_error_class_for_unsuccessful_responses
    resp = fixture_path("v2-public-forms-481580-inventory")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/481580/inventory", :response => resp)

    exception = assert_raises WebconnexAPI::Error do
      WebconnexAPI::InventoryRecord.all_by_form_id(481580)
    end
    assert_includes exception.message, "400"
    assert_includes exception.message, "inventory not generated till form is published"
  end
end
