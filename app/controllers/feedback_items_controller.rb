class FeedbackItemsController < ApplicationController
  wrap_parameters false
  def update_feedback_items
    begin
      batch_params["feedback_items"].each do |patched_item|
        item = FeedbackItem.where(document_inference_id: patched_item["document_inference_id"], user_id: patched_item["user_id"]).first_or_create
        item.assign_attributes(patched_item)
        item.save!
      end
    rescue
      return render json: {error: "Error updating feedback items."}, status: :unprocessable_entity
    end
    render json: {success: true}
  end

  def delete_items
    batch_params["feedback_items"].each do |patched_item|
      FeedbackItem.where(document_inference_id: patched_item["document_inference_id"], user_id: patched_item["user_id"]).destroy_all
    end
  end

  private

  def batch_params
    params.permit(feedback_items: [:id, :document_inference_id, :user_id, :sentiment, :comment]).to_h
  end
end
