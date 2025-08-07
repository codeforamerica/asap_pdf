class FeedbackItemsController < ApplicationController
  def update_feedback_items
    begin
      batch_params["feedback_items"].each { |patched_item|
        if patched_item["id"].nil?
          item = FeedbackItem.where(patched_item["document_inference_id"]).first_or_initialize
        else
          item = FeedbackItem.find(patched_item["id"])
        end
        item.sentiment = patched_item["sentiment"]
        item.comment = patched_item["comment"]
        item.save!
      }
    rescue
      return render json: { error: "Error updating feedback items." }, status: :unprocessable_entity
    end
    render json: { success: true }
  end

  private

  def batch_params
    params.permit(feedback_items: [:id, :document_inference_id, :sentiment, :comment]).to_h
  end
end
