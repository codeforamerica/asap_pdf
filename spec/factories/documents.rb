FactoryBot.define do
  factory :document do
    file_name { "example.pdf" }
    url { "http://example.com/example.pdf" }
    document_status { "Active" }
    document_category { "Brochure" }
    number_of_images { 0 }
    number_of_tables { 0 }
    site
  end
end
