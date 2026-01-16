source "https://rubygems.org"

gem "rails", "~> 8.1.1"
gem "propshaft"
gem "pg"
gem "puma", ">= 5.0"
gem "jsbundling-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "cssbundling-rails", "~> 1.4.3"
gem "csv"
gem "httpparty"
gem "rubyzip"
gem "smarter_csv"
gem "chartkick"

gem "tzinfo-data", platforms: %i[windows jruby]

gem "bootsnap", require: false
gem "thruster", require: false

gem "view_component", "~> 4.1"
gem "kaminari", "~> 1.2"

gem "devise", "~> 4.9.4"
gem "activerecord-session_store"

group :development, :test do
  gem "brakeman", "~> 7.1", require: false
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "dotenv-rails", "~> 3.1"
  gem "standard"
end

group :development do
  gem "overcommit", "~> 0.68.0"
  gem "better_errors", "~> 2.10"
  gem "ruby-lsp", "~> 0.26"
  gem "web-console"
  gem "dockerfile-rails", ">= 1.7.9"
  gem "bundler-audit", "~> 0.9.2"
end

group :test do
  gem "rspec", "~> 3.13"
  gem "rspec-rails", "~> 8.0"
  gem "shoulda", "~> 4.0"
  gem "shoulda-matchers", "~> 4.5"
  gem "simplecov", require: false
  gem "rails-controller-testing"
  gem "factory_bot_rails", "~> 6.5"
  gem "capybara"
  gem "capybara-email"
  gem "selenium-webdriver", "~> 4.38"
end

gem "bcrypt", "~> 3.1"
gem "aws-sdk-s3", "~> 1.208"  # For S3 versioning support
gem "aws-sdk-secretsmanager"
gem "aws-sdk-lambda"
gem "aws-sigv4"

# API and Documentation
gem "grape", "~> 2.4"
gem "grape-swagger"

gem "paper_trail", "~> 17.0"
