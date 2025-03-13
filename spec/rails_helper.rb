require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
ENV["RAILS_ENV"] = "test" if ENV["RAILS_ENV"] == "development"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "rails-controller-testing"
require "shoulda/matchers"
require "capybara/rails"

Capybara.default_driver = :selenium_chrome

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [
    Rails.root.join("spec/fixtures")
  ]

  config.use_transactional_fixtures = true

  # Clean the database between tests
  config.before(:each) do
    Site.destroy_all
  end

  config.filter_rails_from_backtrace!

  config.include Rails::Controller::Testing::TestProcess, type: :controller
  config.include Rails::Controller::Testing::TemplateAssertions, type: :controller
  config.include Rails::Controller::Testing::Integration, type: :controller

  # Configure API specs to use Rack::Test
  config.include Rack::Test::Methods, type: :api

  config.define_derived_metadata(file_path: %r{spec/requests/api}) do |metadata|
    metadata[:type] = :api
  end

  # Helper to get the Grape API app
  def app
    AsapPdf::API
  end

  Shoulda::Matchers.configure do |shoulda_config|
    shoulda_config.integrate do |with|
      with.test_framework :rspec
      with.library :rails
    end
  end
end
