require "grape"
require "grape-swagger"

module AsapPdf
  class API < Grape::API::Instance
    format :json

    rescue_from ActiveRecord::RecordNotFound do |e|
      error!({error: e.message}, 404)
    end

    desc "Return list of sites" do
      detail "Returns a list of all sites in the system"
      tags ["Sites"]
      produces ["application/json"]
      failure [[401, "Unauthorized"], [403, "Forbidden"]]
    end
    get "/sites" do
      Site.all
    end

    desc "Return a specific site" do
      detail "Returns detailed information about a specific site"
      tags ["Sites"]
      produces ["application/json"]
      failure [
        [401, "Unauthorized"],
        [403, "Forbidden"],
        [404, "Site not found"]
      ]
    end
    params do
      requires :id, type: Integer, desc: "Site ID"
    end
    get "/sites/:id" do
      Site.find(params[:id])
    end

    desc "Discover documents for a site" do
      detail "Creates or updates documents for a specific site based on the provided URLs and timestamps"
      tags ["Documents"]
      produces ["application/json"]
      consumes ["application/json"]
      failure [
        [400, "Bad Request - Invalid parameters"],
        [401, "Unauthorized"],
        [403, "Forbidden"],
        [404, "Site not found"]
      ]
      named "Create Documents"
    end
    params do
      requires :id, type: Integer, desc: "Site ID"
      requires :documents, type: Array do
        requires :url, type: String, desc: "Document URL"
        requires :modification_date, type: DateTime, desc: "Document's last modified timestamp"
      end
    end
    post "/sites/:id/documents" do
      site = Site.find(params[:id])
      documents = site.discover_documents!(params[:documents])

      status 201
      {documents: documents.map { |doc|
        {
          id: doc.id,
          url: doc.url,
          document_status: doc.document_status,
          s3_path: doc.s3_path
        }
      }}
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
      requires :documents, type: Array do
        requires :document_id, type: Integer, desc: "Document ID"
        requires :type, type: String, desc: "Document inference type"
        requires :value, type: String, desc: "Value of document inference"
      end
    end
    post "/documents/inference" do
      status 201
      params[:documents].map do |doc|
        inference = DocumentInference.create_or_find_by(document_id: doc[:document_id], inference_type: doc[:type])
        inference.inference_value = doc[:value]
        inference.inference_confidence = doc[:confidence] if doc[:confidence].present?
        inference.inference_reason = doc[:reason] if doc[:reason].present?
        inference.save!
      end
    end

    add_swagger_documentation(
      mount_path: "/swagger_doc",
      openapi_version: "3.0.1",
      info: {
        title: "ASAP PDF API",
        description: "API for managing ASAP PDF resources and document processing",
        version: "1.0.0"
      },
      tags: [
        {name: "Sites", description: "Site management operations"},
        {name: "Documents", description: "Document processing operations"}
      ],
      components: {
        schemas: {
          Site: {
            type: "object",
            properties: {
              id: {type: "integer", description: "Site ID"},
              name: {type: "string", description: "Site name"},
              location: {type: "string", description: "Site location"},
              primary_url: {type: "string", description: "Primary URL of the site"}
            },
            required: ["id", "name", "location", "primary_url"]
          },
          Document: {
            type: "object",
            properties: {
              id: {type: "integer", description: "Document ID"},
              url: {type: "string", description: "Document URL"},
              document_status: {type: "string", description: "Current status of the document"},
              s3_path: {type: "string", description: "S3 storage path"}
            },
            required: ["id", "url", "document_status", "s3_path"]
          }
        }
      }
    )
  end
end
