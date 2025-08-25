class DocumentsController < AuthenticatedController
  include Access
  include ParamsHelper

  protect_from_forgery with: :exception
  skip_before_action :verify_authenticity_token, only: [:update_document_category, :update_accessibility_recommendation, :update_notes, :update_summary_inference, :update_recommendation_inference]
  before_action :set_site, only: [:index, :insights, :audit_exports, :modal_content, :batch_update]
  before_action :set_document, except: [:index, :insights, :audit_exports, :batch_update]
  before_action :ensure_user_site_access, only: [:index, :insights, :audit_exports, :modal_content, :batch_update]
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

  def insights
    # Build document list.
    @documents = @site.documents
      .by_category(params[:category])
      .by_department(params[:department])
    # Create binned date data for visualization.
    # First, gather all documents by year
    year_groups = @documents.group_by(&:modification_year).map { |label, year_documents| [label, year_documents.size] }
    # Extract and remove "Unknown" to handle separately
    unknown_group = year_groups.find { |item| item[0] == "Unknown" }
    year_groups = year_groups.reject { |item| item[0] == "Unknown" }
    year_groups = year_groups.select do |item|
      Integer(item[0])
      true
    rescue
      if unknown_group.nil?
        unknown_group = ["Unknown", 0]
      end
      unknown_group[1] += 1
      false
    end
    # Convert to integers for sorting and calculations
    year_groups = year_groups.map { |year, count| [Integer(year), count] }
    # Create bins based on specific year ranges
    binned_data = []
    bins = [
      ["< 2000", -Float::INFINITY..1999],
      ["2000-2005", 2000..2005],
      ["2006-2011", 2006..2011],
      ["2012-2017", 2012..2017],
      ["2018-2023", 2018..2023],
      ["> 2023", 2024..Float::INFINITY]
    ]
    bins.each do |label, range|
      count = year_groups.filter_map { |year, count| count if range.cover?(year) }.sum
      binned_data << [label, count]
    end
    # Add the "Unknown" group if it exists (placing it at the end)
    binned_data << unknown_group if unknown_group
    @document_years = binned_data
    # Create table data.
    default_group = Document::DECISION_TYPES.keys.map { |status| [status, 0] }.to_h
    @category_groups = {}
    @documents.group([:document_category, :accessibility_recommendation]).count.each do |groups, group_count|
      @category_groups[groups[0]] = default_group.clone if @category_groups[groups[0]].nil?
      if Document::DECISION_TYPES.keys.exclude? groups[1]
        parent = Document::DECISION_TYPES.keys.find do |key|
          if Document::DECISION_TYPES[key]["children"].present? && Document::DECISION_TYPES[key]["children"].key?(groups[1])
            key
          end
        end
        if parent.present?
          groups[1] = parent
        end
      end
      @category_groups[groups[0]][groups[1]] += group_count
    end
    @category_groups.each do |key, child_hash|
      sum = child_hash.values.sum
      child_hash["Total"] = sum
    end
    @category_groups = @category_groups.sort.to_h
    # Work on document links.
    @document_links = {
      complexity: [
        {title: Document::SIMPLE_STATUS, params: query_params.merge({complexity: Document::SIMPLE_STATUS})},
        {title: Document::COMPLEX_STATUS, params: query_params.merge({complexity: Document::COMPLEX_STATUS})}
      ],
      years: bins.map do |label, range|
        document_count = @document_years.find { |item| item[0] == label }
        if document_count[1] == 0
          next
        end
        start_date = (range.begin == -Float::INFINITY) ? nil : "#{range.begin}-01-01"
        end_date = (range.end == Float::INFINITY) ? nil : "#{range.end}-12-31"
        {
          title: label,
          params: query_params.merge(
            start_date: start_date,
            end_date: end_date
          ).compact
        }
      end.compact,
      decision: @documents.pluck(:accessibility_recommendation).uniq.map do |decision|
        {
          title: decision,
          params: query_params.merge(
            accessibility_recommendation: decision
          )
        }
      end
    }
  end

  def audit_exports
    @export_links = []
    @error_message = nil
    begin
      @export_links = @site.get_document_audit_link_hashes!
    rescue => e
      @error_message = e.message
    end
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
    handle_pdf_error(nil, e.message)
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
      @document.inference_summary! request.base_url
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
        exception.is_active = false
        exception.save!
      end
    end
    @document.inference_recommendation! request.base_url
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
    error_code ||= "unknown"
    Rails.logger.error("PDF fetch error: #{error_code} - #{error_message}")
    render "shared/iframe_error", layout: "simple", locals: {document: @document, error_code: error_code, error_message: error_message}, formats: [:html]
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : "desc"
  end
end
