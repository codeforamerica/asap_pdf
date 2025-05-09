require "csv"
require "zip"
require "rake"

# Create a test user for development
if Rails.env.development?
  Rake::Task["users:create_admin"].invoke("password")
  Rake::Task["documents:bootstrap"].invoke
  Rake::Task["documents:update_department"].invoke("1")
  Rake::Task["documents:add_pdf_complexity"].invoke
end
