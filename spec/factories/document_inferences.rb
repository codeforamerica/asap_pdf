FactoryBot.define do
  factory :document_inference do
    creation_date { Time.current }
    inference_type { "exception:is_application" }
    inference_value { "True" }
    inference_confidence { 0.85 }
    inference_reason { "This is an event flyer for a for a croquet party." }
    is_active { true }
    inference_model_name { "gemini-2.0-flash" }
    token_details { "input_tokens: 150, output_tokens: 25" }
    document
  end
end
