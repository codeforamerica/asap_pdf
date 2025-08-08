class FeedbackItem < ApplicationRecord
  SENTIMENT_TYPES = %w[positive negative]

  belongs_to :document_inference

  validates :sentiment, inclusion: {in: SENTIMENT_TYPES}, presence: true
end
