class SitesController < AuthenticatedController
  include Access
  include ParamsHelper

  before_action :find_site, only: [:show, :edit, :update, :destroy]
  before_action :ensure_user_site_access, only: [:show, :edit, :update, :destroy]

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

  private

  def site_params
    params.require(:site).permit(:name, :location, :primary_url)
  end

  def find_site
    @site = Site.find(params[:id])
  end
end
