require "grape"
require "grape-swagger"

module AsapPdf
  class API < Grape::API::Instance
    format :json

    http_basic do |email, password|
      @user = User.find_by(email: email)
      @user&.valid_password?(password)
    end

    rescue_from ActiveRecord::RecordNotFound do |e|
      error!({ error: e.message }, 404)
    end

    desc "Return list of sites" do
      detail "Returns a list of all sites the user has access to."
      tags ["Sites"]
      produces ["application/json"]
      failure [[401, "Unauthorized"], [403, "Forbidden"]]
      security [{ basic_auth: [] }]
    end
    get "/sites" do
      @user.is_site_admin ? Site.all : [@user.site]
    end

    desc "List documents related to site." do
      detail "A paginated list of documents related to a site."
      tags ["Documents"]
      produces ["application/json"]
      consumes ["application/json"]
      failure [
                [400, "Bad Request - Invalid parameters"],
                [401, "Unauthorized"],
                [403, "Forbidden"],
                [404, "Site not found"]
              ]
      named "List documents"
    end
    params do
      requires :id, type: Integer, desc: "Site ID"
      optional :page, type: Integer, desc: 'Page number for pagination', default: 0
      optional :items_per_page, type: Integer, desc: 'Items per page', default: 25
    end
    get "/sites/:id/documents" do
      items_per_page = params[:items_per_page].nil? ? 25 : params[:items_per_page].to_i
      page = params[:page].nil? ? 0 : params[:page].to_i
      unless @user.is_site_admin || params[:id] == @user.site_id
        { documents: [] }
      end
      site = Site.find(params[:id])
      { documents: site.documents.limit(items_per_page).offset(page * items_per_page).order(id: :asc) }
    end

    desc "List document inferences for a document." do
      detail "List LLM document inferences (summary or exception check) for a document."
      tags ["Document Inferences"]
      produces ["application/json"]
      consumes ["application/json"]
      failure [
                [400, "Bad Request - Invalid parameters"],
                [401, "Unauthorized"],
                [403, "Forbidden"],
                [404, "Site not found"]
              ]
    end
    params do
      requires :id, type: Integer, desc: "Document ID"
    end
    get "/documents/:id/inference" do
      status 201
      document = Document.find(params[:id])
      { document_inferences: document.document_inferences.order(id: :asc) }
    end

    desc "Adds or updates a document inference with type" do
      detail "Adds or updates a document inference with the provided type and document id."
      tags ["Document Inferences"]
      produces ["application/json"]
      consumes ["application/json"]
      failure [
                [400, "Bad Request - Invalid parameters"],
                [401, "Unauthorized"],
                [403, "Forbidden"],
                [404, "Site not found"]
              ]
    end
    params do
      requires :id, type: Integer, desc: "Document ID"
      requires :inference_type, type: String, desc: "Document inference type", values: ["summary", "exception"]
      optional :result, type: Hash, desc: "Value of document inference" do
        optional "summary", type: String, desc: "For inference_type summary, generated summary"
        optional "is_<exception type>", type: String, desc: "For inference_type exception, the exception type"
        optional "why_<exception type>", type: String, desc: "For inference_type exception, the LLM explanation"
      end
    end
    post "/documents/:id/inference" do
      status 201
      if params[:inference_type] == "summary"
        inference = DocumentInference.create(document_id: params[:id], inference_type: "summary")
        inference.inference_value = params[:result]["summary"]
        inference.is_active = true
        inference.save!
      end
      if params[:inference_type] == "exception"
        ["individualized", "archival", "application", "third_party"].each do |type|
          result_boolean = "is_#{type}"
          unless params[:result][result_boolean].nil?
            inference = DocumentInference.create(document_id: params[:id], inference_type: "exception:#{result_boolean}")
            inference.inference_value = params[:result][result_boolean] ? "True" : "False"
            inference.inference_confidence = params[:result]["#{result_boolean}_confidence"]
            inference.inference_reason = params[:result]["why_#{type}"]
            inference.is_active = true
            inference.save!
          end
        end
      end
    end

    add_swagger_documentation(
      doc_version: "1.0.0",
      mount_path: "/swagger_doc",
      info: {
        title: "ASAP PDF API",
        description: "API for managing ASAP PDF resources and document processing. <strong>Note: Basic authentication is required for all endpoints.</strong>",
        version: "1.0.0"
      },
      tags: [
        { name: "Sites", description: "Site operations" },
        { name: "Documents", description: "Document operations" },
        { name: "Document Inferences", description: "Document Inference operations" }
      ],
      models: [],
    )
  end
end
