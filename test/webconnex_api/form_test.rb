require 'test_helper'

class TestWebconnexAPIForm < Test::Unit::TestCase
  # To grab a fixture in plaintext (set an ID)
  # curl --http1.1 -X "GET" -is "https://api.webconnex.com/v2/public/forms/$ID" -H "apiKey: $WEBCONNEX_API_KEY" -H "Accept: */*" -H "User-Agent: Ruby" -H "Host: api.webconnex.com" > test/fixtures/v2-public-forms-$ID
  #
  # Useful fixtures:
  # 481580 - unpublished, archived form with same name as a published one
  # 481581 - the published one

  def test_form_find_does_not_raise
    resp = fixture_path("v2-public-forms-481581")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/481580", :response => resp)
    WebconnexAPI::Form.find(481580)
  end

  def test_form_published_returns_false_when_published_path_is_missing
    resp = fixture_path("v2-public-forms-481580")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/481580", :response => resp)
    form = WebconnexAPI::Form.find(481580)
    assert form["publishedPath"].nil?
    assert !form.published?
  end

  def test_form_published_returns_true_when_published_path_is_present
    resp = fixture_path("v2-public-forms-481581")
    FakeWeb.register_uri(:get, "https://api.webconnex.com/v2/public/forms/481581", :response => resp)
    form = WebconnexAPI::Form.find(481581)
    assert !form["publishedPath"].nil?
    assert form.published?
  end
end
