module Access
  def ensure_user_site_admin
    unless current_user.is_site_admin?
      redirect_to sites_path, alert: "You don't have permission to access that page."
    end
  end

  def ensure_user_user_admin
    unless current_user.is_user_admin?
      redirect_to sites_path, alert: "You don't have permission to access that page."
    end
  end

  def ensure_user_site_access
    if !current_user.is_site_admin? && (current_user.site.nil? || current_user.site.id != @site.id)
      redirect_to sites_path, alert: "You don't have permission to access that site."
    end
  end

  def ensure_user_document_access
    if !current_user.is_site_admin? && (current_user.site.nil? || current_user.site.documents.find(@document.id).nil?)
      redirect_to sites_path, alert: "You don't have permission to perform that action on document."
    end
  end
end
