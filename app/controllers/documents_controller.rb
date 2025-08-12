class DocumentsController < AuthenticatedController
  include Access
  include ParamsHelper

  protect_from_forgery with: :exception
  skip_before_action :verify_authenticity_token, only: [:update_document_category, :update_accessibility_recommendation, :update_notes, :update_summary_inference, :update_recommendation_inference]
  before_action :set_site, only: [:index, :modal_content, :batch_update]
  before_action :set_document, except: [:index, :batch_update]
  before_action :ensure_user_site_access, only: [:index, :modal_content, :batch_update]
  before_action :ensure_user_document_access, except: [:index, :modal_content, :batch_update]

  def modal_content
    render partial: "modal_content", locals: {document: @document}
  end

  def index
    @documents = @site.documents
      .by_filename(params[:filename])
      .by_category(params[:category])
      .by_decision_type(params[:accessibility_recommendation])
      .by_department(params[:department])
      .by_complexity(params[:complexity])
      .by_date_range(params[:start_date], params[:end_date])
      .order(sort_column => sort_direction)
      .page(params[:page])
    @total_documents = @documents.total_count
    @decision_values = Document.get_decision_types.reject { |k, v| k == (params[:accessibility_recommendation].present? ? params[:accessibility_recommendation] : Document::DEFAULT_DECISION) }.to_h

    @filters_for_sorts = query_params [:sort, :direction, :page]
  end

  def serve_document_url
    response = HTTParty.get(@document.normalized_url)
    if response.success?
      send_data response.body,
                type: "application/pdf",
                disposition: "inline; filename=\"#{@document.file_name}\"",
                filename: @document.file_name
    else
      handle_pdf_error(response.code, response.message)
    end
    rescue HTTParty::Error => e
      handle_pdf_error(e.http_code, e.message)
    rescue => e
      handle_pdf_error("Unknown Error", e.message)
  end

  def update_document_category
    value = params[:value].presence
    if @document.update(document_category: value)
      render json: {
        display_text: value
      }
    else
      render json: {error: @document.errors.full_messages}, status: :unprocessable_entity
    end
  end

  def update_accessibility_recommendation
    value = params[:value].presence || Document::DEFAULT_ACCESSIBILITY_RECOMMENDATION
    if @document.update(accessibility_recommendation: value)
      render json: {
        display_text: value
      }
    else
      render json: {error: @document.errors.full_messages}, status: :unprocessable_entity
    end
  end

  def update_notes
    if @document.update(notes: params[:document][:notes])
      render json: {
        display_text: params[:document][:notes].present? ? params[:document][:notes] : "No notes"
      }
    else
      render json: {error: @document.errors.full_messages}, status: :unprocessable_entity
    end
  end

  def update_summary_inference
    if @document.summary.nil?
      @document.inference_summary!
      @document.reload
    end
    render json: {
      display_text: @document.summary
    }
  end

  def update_recommendation_inference
    exceptions = @document.exceptions(false)
    if exceptions.present?
      exceptions.each do |exception|
        exception.destroy
      end
    end
    @document.inference_recommendation!
    @document.reload
    render json: {html: render_to_string(partial: "documents/recommendation_list", formats: [:html], locals: {document: @document})}
  end

  def batch_update
    begin
      documents = batch_params["documents"]
      ActiveRecord::Base.transaction do
        documents.each do |update|
          document = Document.find(update["id"])
          unless document.update(update)
            raise ActiveRecord::Rollback
          end
        end
      end
    rescue
      return render json: {error: "Error updating documents."}, status: :unprocessable_entity
    end
    render json: {success: true}
  end

  private

  def batch_params
    params.permit(:site_id, document: {}, documents: [:id, :accessibility_recommendation]).to_h
  end

  def set_site
    @site = Site.find(params[:site_id])
  end

  def set_document
    @document = Document.find(params[:id])
  end

  def sort_column
    if params[:sort] == "document_category"
      "document_category_confidence"
    else
      %w[file_name modification_date accessibility_recommendation].include?(params[:sort]) ? params[:sort] : "document_category_confidence"
    end
  end

  def handle_pdf_error(error_code, error_message)
    Rails.logger.error("PDF fetch error: #{error_code} - #{error_message}")
    render 'shared/iframe_error', layout: 'simple', locals: {document: @document, error_code: error_code, error_message: error_message}
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : "desc"
  end
end
