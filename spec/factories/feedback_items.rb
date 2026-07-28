FactoryBot.define do
  factory :feedback_item do
    sentiment { "positive" }
    comment { "Looks right." }
    document_inference
    user
  end
end
