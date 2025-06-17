FactoryBot.define do
  factory :document do
    file_name { "example.pdf" }
    url { "http://example.com/example.pdf" }
    document_status { "discovered" }
    document_category { "Brochure" }
    site
  end
end
