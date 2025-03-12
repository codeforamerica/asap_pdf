class DocumentInference < ApplicationRecord
  belongs_to :document

  INFERENCE_TYPES = {
    summary: {
      label: "Summary"
    },
    "exception:is_archival": {
      label: "Archived web content",
      url: "https://www.ada.gov/resources/2024-03-08-web-rule/#1-archived-web-content"
    },
    "exception:is_application": {
      label: "Preexisting documents",
      url: "https://www.ada.gov/resources/2024-03-08-web-rule/#2-preexisting-conventional-electronic-documents"
    },
    "exception:is_third_party": {
      label: "Third party content",
      url: "https://www.ada.gov/resources/2024-03-08-web-rule/#3-content-posted-by-a-third-party-where-the-third-party-is-not-posting-due-to-contractual-licensing-or-other-arrangements-with-a-public-entity"
    },
    "exception:is_individualized": {
      label: "Individualized documents",
      url: "https://www.ada.gov/resources/2024-03-08-web-rule/#4-individualized-documents-that-are-password-protected"
    }
  }.freeze

  validates :inference_type, inclusion: {in: INFERENCE_TYPES.keys}, presence: true
  validates :inference_value, presence: true
end
