module ParamsHelper
  def query_params(exclude = [])
    params.to_unsafe_h.except(:controller, :action, :site_id, :id, :format, *exclude)
  end
end
