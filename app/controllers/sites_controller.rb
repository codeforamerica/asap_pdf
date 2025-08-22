class SitesController < AuthenticatedController
  include Access
  include ParamsHelper

  before_action :find_site, only: [:show, :edit, :update, :destroy, :create_workflow_audit_report]
  before_action :ensure_user_site_access, only: [:show, :edit, :update, :destroy, :workflow_audit_report]

  def index
    @sites = if current_user.is_site_admin?
      Site.all
    else
      current_user.site.nil? ? [] : [current_user.site]
    end
  end

  def show
    @documents = @site.documents.order(created_at: :desc)
  end

  def new
    @site = Site.build
  end

  def create
    @site = Site.build(site_params)

    if @site.save
      redirect_to sites_path, notice: "Site was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @site.update(site_params)
      redirect_to @site, notice: "Site was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @site.destroy
    redirect_to sites_path, notice: "Site was successfully deleted.", status: :see_other
  end

  def create_workflow_audit_report
    @site.export_document_audit
    render json: {html: render_to_string(partial: "documents/audit_export_list", formats: [:html], locals: {site: @site})}
  end

  def workflow_audit_report
    s3_manager = AwsS3Manager.new
    begin
      key = params[:key]
      key = key.start_with?("/") ? key : "/#{key}"
      response = s3_manager.get_object(params[:bucket_name], key)
      send_data response[:body].read,
                filename: File.basename(key),
                type: response[:content_type] || 'application/octet-stream',
                disposition: 'inline'
    rescue Aws::S3::Errors::NoSuchKey
      render plain: 'File not found', status: 404
    rescue => e
      Rails.logger.error "S3 error: #{e.message}"
      render plain: 'Error retrieving file', status: 500
    end
  end

  private

  def site_params
    params.require(:site).permit(:name, :location, :primary_url)
  end

  def find_site
    @site = Site.find(params[:id])
  end
end
