class SitesController < AuthenticatedController
  include Access
  before_action :find_site, only: [:insights, :show, :edit, :update, :destroy]
  before_action :ensure_user_site_access, only: [:insights, :show, :edit, :update, :destroy]

  def index
    @sites = if Current.user.is_admin?
      Site.all
    else
      Current.user.site.nil? ? [] : [Current.user.site]
    end
  end

  def insights
    # Build document list.
    @documents = @site.documents
      .by_category(params[:category])
      .by_department(params[:department])
    if params[:status].present?
      @documents.by_status(params[:status])
    end
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
    default_group = Document::STATUSES.map { |status| [status, 0] }.to_h
    @category_groups = {}
    @documents.group([:document_category, :status]).count.each do |groups, group_count|
      @category_groups[groups[0]] = default_group.clone if @category_groups[groups[0]].nil?
      @category_groups[groups[0]][groups[1]] = group_count
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

  def query_params
    params.to_unsafe_h.except(:controller, :action, :site_id, :id, :format)
  end

  def find_site
    @site = Site.find(params[:id])
  end
end
