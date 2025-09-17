FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password" }
    trait :site_admin do
      is_site_admin { true }
    end
  end
end
