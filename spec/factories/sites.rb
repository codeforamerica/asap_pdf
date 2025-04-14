FactoryBot.define do
  factory :site do
    name { "Example Site #{(0...8).map { (65 + rand(26)).chr }.join}" }
    location { "Example Location" }
    primary_url { "http://#{(0...8).map { (65 + rand(26)).chr }.join}.example.com" }
  end
end
