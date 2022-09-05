Gem::Specification.new do |s|
  s.name    = "webconnex_api"
  s.version = "0.1pre"
  s.license = "MIT"
  s.author  = "Chris Kampmeier"
  s.email   = "chris@kampers.net"

  s.summary = "API client for Webconnex"
  s.description = "An API client for Webconnex, initially built to retrieve " +
                  "data from TicketSpice. See https://docs.webconnex.io/api/v2/"

  s.homepage = "https://github.com/therentheatre/webconnex_api"
  s.metadata = {
    "source_code_uri" => "https://github.com/therentheatre/webconnex_api"
  }

  root_docs = %w(LICENSE README.md)
  s.extra_rdoc_files = root_docs
  s.files = Dir["lib/**/*.rb"] + root_docs

  # Gem dependencies are auto-discovered from the Gemfile
  # (more info: `gem help gem_dependencies`)
end
