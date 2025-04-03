require "csv"
require "rake"
Rails.application.load_tasks

# Create a test user for development
if Rails.env.development?
  Rake::Task["users:create_admin"].invoke("password")
  Rake::Task["documents:bootstrap"].invoke
end
