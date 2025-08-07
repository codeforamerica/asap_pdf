class FeedbackItem < ApplicationRecord
  SENTIMENT_TYPES = %w[Positive Negative]

  belongs_to :document_inference

  validates sentiment: {in: SENTIMENT_TYPES}, presence: true
end
