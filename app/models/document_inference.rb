class DocumentInference < ApplicationRecord

  INFERENCE_TYPES = ["summary", "exception:is_application", "exception:why_application",
                     "exception:is_individualized", "exception:why_individualized",
                     "exception:is_archival", "exception:why_archival", "exception:is_third_party",
                     "exception:why_third_party"].freeze

  validates :inference_type, inclusion: {in: INFERENCE_TYPES}, presence: true
  validates :inference_value, presence: true

end
