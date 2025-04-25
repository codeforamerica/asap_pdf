FactoryBot.define do
  factory :site do
    name { "Example Site #{(0...8).map { rand(65..90).chr }.join}" }
    location { "Example Location" }
    primary_url { "http://#{(0...8).map { rand(65..90).chr }.join}.example.com" }
  end
end
