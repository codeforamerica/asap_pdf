class SiteDocumentAuditExportJob
  include Sidekiq::Job

  def perform(*args)
    Site.find(args[0]).export_document_audit
  end
end
