FactoryBot.define do
  factory :user do
    email { "user#{rand(1000)}@example.com" }
    password { "password" }
    trait :site_admin do
      is_site_admin { true }
    end
  end
end
