# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.verbose = false
  t.warning = true
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*.rb"].exclude("test/test_helper.rb",
                                                  "test/helpers/**/*")
end

task :print_ruby_version do
  version_string = `command -v rvm >/dev/null && rvm current`.strip
  version_string = RUBY_DESCRIPTION if !$?.success?
  puts "\n# Starting tests using \e[1m#{version_string}\e[0m\n\n"
end

Rake::Task[:test].enhance [:print_ruby_version]
task default: :test
