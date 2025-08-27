FactoryBot.define do
  factory :document_inference do
    creation_date { Time.current }
    inference_type { "exception:is_application" }
    inference_value { "True" }
    inference_confidence { 0.85 }
    inference_reason { "This is an event flyer for a for a croquet party." }
    is_active { true }
    document
  end
end
