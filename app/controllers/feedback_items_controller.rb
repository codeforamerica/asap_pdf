class FeedbackItemsController < AuthenticatedController
  wrap_parameters false

  def update_feedback_items
    batch_params["feedback_items"].each do |patched_item|
      inference = authorized_inference!(patched_item["document_inference_id"])
      item = FeedbackItem.where(document_inference_id: inference.id, user_id: current_user.id).first_or_create
      item.assign_attributes(patched_item)
      item.save!
    end
    render json: {success: true}
  rescue ActiveRecord::RecordNotFound
    render json: {error: "Feedback target not found."}, status: :not_found
  rescue
    render json: {error: "Error updating feedback items."}, status: :unprocessable_entity
  end

  def delete_items
    batch_params["feedback_items"].each do |patched_item|
      inference = authorized_inference!(patched_item["document_inference_id"])
      FeedbackItem.where(document_inference_id: inference.id, user_id: current_user.id).destroy_all
    end
    head :no_content
  rescue ActiveRecord::RecordNotFound
    render json: {error: "Feedback target not found."}, status: :not_found
  end

  private

  def authorized_inference!(document_inference_id)
    inference = DocumentInference.find(document_inference_id)
    unless current_user.is_site_admin? || current_user.site == inference.document.site
      raise ActiveRecord::RecordNotFound
    end
    inference
  end

  def batch_params
    params.permit(feedback_items: [:document_inference_id, :sentiment, :comment]).to_h
  end
end
