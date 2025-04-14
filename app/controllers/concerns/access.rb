module Access
  def ensure_user_site_access
    if !Current.user.is_admin? && (Current.user.site.nil? || Current.user.site.id != @site.id)
      redirect_to sites_path, alert: "You don't have permission to access that site."
    end
  end

  def ensure_document_access
    if !Current.user.is_admin? && (Current.user.site.nil? || Current.user.site.documents.find(@document.id).nil?)
      redirect_to sites_path, alert: "You don't have permission to perform that action on document."
    end
  end
end
