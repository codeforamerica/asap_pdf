class DocumentsController < AuthenticatedController
  include Access

  protect_from_forgery with: :exception
  skip_before_action :verify_authenticity_token, only: [:update_document_category, :update_accessibility_recommendation, :update_status, :update_notes, :update_summary_inference, :update_recommendation_inference]
  before_action :set_site, only: [:index, :modal_content]
  # before_action :set_site, except: [:update_document_category, :update_accessibility_recommendation, :update_notes, :update_summary_inference, :update_recommendation_inference]
  # before_action :set_document_for_update, only: [:update_document_category, :update_accessibility_recommendation, :update_notes, :update_summary_inference, :update_recommendation_inference, :update_status]
  before_action :set_document, except: [:index]
  before_action :ensure_user_site_access, only: [:index, :modal_content]
  before_action :ensure_document_access, except: [:index, :modal_content]

  def modal_content
    render partial: "modal_content", locals: {document: @document}
  end

  def index
    @documents = @site.documents
      .by_status(params[:status])
      .by_filename(params[:filename])
      .by_category(params[:category])
      .by_decision_type(params[:accessibility_recommendation])
      .by_date_range(params[:start_date], params[:end_date])
      .order(sort_column => sort_direction)
      .page(params[:page])
    @document_categories = Document::CONTENT_TYPES
    @document_decisions = Document::DECISION_TYPES.keys
    @total_documents = @documents.total_count
  end

  def update_document_category
    value = params[:value].presence || Document::DEFAULT_DOCUMENT_CATEGORY
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

  def update_status
    # Set Unknown as default for empty values
    existing_recommendation = @document.accessibility_recommendation || Document::DEFAULT_ACCESSIBILITY_RECOMMENDATION
    existing_category = @document.document_category || Document::DEFAULT_DOCUMENT_CATEGORY

    if @document.update(
      status: params[:status],
      accessibility_recommendation: existing_recommendation,
      document_category: existing_category
    )
      render json: {success: true}
    else
      render json: {success: false, error: @document.errors.full_messages}, status: :unprocessable_entity
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
    if @document.exceptions(false).none?
      @document.inference_recommendation!
      @document.reload
    end
    render json: {html: render_to_string(partial: "documents/recommendation_list", formats: [:html], locals: {document: @document})}
  end

  private

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

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : "desc"
  end
end
