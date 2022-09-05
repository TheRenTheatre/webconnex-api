require 'test_helper'

class TestWebconnexAPIForm < Test::Unit::TestCase
  # To grab a fixture in plaintext (set an ID)
  # curl --http1.1 -X "GET" -is "https://api.webconnex.com/v2/public/forms/$ID" -H "apiKey: $WEBCONNEX_API_KEY" -H "Accept: */*" -H "User-Agent: Ruby" -H "Host: api.webconnex.com" > test/fixtures/v2-public-forms-$ID
  #
  # Useful fixtures:
  # 481580 - unpublished, archived form with same name as a published one

  def test_form_find_does_not_raise
    resp = fixture_path("v2-public-forms-481581")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/481580", :response => resp)
    WebconnexAPI::Form.find(481580)
  end
end
