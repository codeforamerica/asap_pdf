require "rails_helper"

RSpec.describe AsapPdf::API do
  include Rack::Test::Methods

  def app
    AsapPdf::API
  end

  def auth_headers user
    encoded_credentials = ActionController::HttpAuthentication::Basic.encode_credentials(user.email, "password")
    { "HTTP_AUTHORIZATION" => encoded_credentials }
  end

  let!(:admin_user) { create(:user, :site_admin) }
  let!(:user) { create(:user) }

  describe "GET /sites" do
    let!(:sites) { create_list(:site, 3) }
    it "blocks access to anonymous users" do
      get "/sites"
      expect(last_response.status).to eq(401)
    end

    it "returns all accessible sites" do
      get "/sites", {}, auth_headers(admin_user)
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body).length).to eq(3)

      get "/sites", {}, auth_headers(user)
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body).length).to eq(0)

      user.site = sites[0]
      user.save!

      get "/sites", {}, auth_headers(user)
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body).length).to eq(1)
    end

    it "returns sites with correct structure" do
      get "/sites", {}, auth_headers(admin_user)
      json_response = JSON.parse(last_response.body)
      first_site = json_response.first

      expect(first_site).to include(
                              "id",
                              "name",
                              "location",
                              "primary_url"
                            )
    end
  end

  describe "GET /sites/:id/documents" do
    let!(:site) { create(:site) }
    let!(:document) { create_list(:document, 10, site: site) }

    it "blocks access to anonymous users" do
      get "/sites/#{site.id}/documents"
      expect(last_response.status).to eq(401)
    end

    it "returns all accessible documents" do
      get "/sites/#{site.id}/documents", {}, auth_headers(admin_user)
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)["documents"].length).to eq(10)

      get "/sites/#{site.id}/documents", {}, auth_headers(user)
      expect(last_response.status).to eq(401)

      user.site = site
      user.save!

      get "/sites/#{site.id}/documents", {}, auth_headers(user)
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)["documents"].length).to eq(10)
    end

    it "paginates" do
      get "/sites/#{site.id}/documents", { "page": 0, "items_per_page": 2 }, auth_headers(admin_user)
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)["documents"].length).to eq(2)
      get "/sites/#{site.id}/documents", { "page": 4, "items_per_page": 2 }, auth_headers(admin_user)
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)["documents"].length).to eq(2)
      get "/sites/#{site.id}/documents", { "page": 5, "items_per_page": 2 }, auth_headers(admin_user)
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)["documents"].length).to eq(0)
    end
  end

  describe "GET /documents/:id/document_inference" do
    let!(:site) { create(:site) }
    let!(:document) { create(:document, site: site) }
    let!(:document_inference) { create_list(:document_inference, 4, document: document) }

    it "blocks access to anonymous users" do
      get "/documents/#{document.id}/document_inference"
      expect(last_response.status).to eq(401)
    end

    it "returns all accessible document inferences" do
      get "/documents/#{document.id}/document_inference", {}, auth_headers(admin_user)
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)["document_inferences"].length).to eq(4)

      get "/documents/#{document.id}/document_inference", {}, auth_headers(user)
      expect(last_response.status).to eq(401)

      user.site = site
      user.save!

      get "/documents/#{document.id}/document_inference", {}, auth_headers(user)
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)["document_inferences"].length).to eq(4)
    end

  end

  describe "POST /documents/:id/inference" do
    let(:timestamp) { Time.current }
    let!(:site) { create(:site) }
    let!(:document) { create(:document, site: site) }
    let(:inference) { { inference_type: "exception", result: { is_archival: "True", why_archival: "This document is in a special archival section." } } }
    let(:inference_update) { { inference_type: "exception", result: { is_archival: "True", why_archival: "This document is in a special archival section.", is_application: "True", why_application: "Test 123" } } }

    context "when the document receives inferences" do
      it "blocks access to anonymous users" do
        post "/documents/#{document.id}/inference", inference
        expect(last_response.status).to eq(401)
      end
      it "creates new inferences" do
        expect {
          post "/documents/#{document.id}/inference", inference, auth_headers(admin_user)
        }.to change(DocumentInference, :count).by(1)
        expect(document.document_inferences.count).to eq(1)
        expect {
          post "/documents/#{document.id}/inference", inference_update, auth_headers(admin_user)
        }.to change(DocumentInference, :count).by(2)
        expect(document.document_inferences.count).to eq(3)

        post "/documents/#{document.id}/inference", inference_update, auth_headers(user)
        expect(last_response.status).to eq(401)
        expect(document.document_inferences.count).to eq(3)

        user.site = site
        user.save!

        post "/documents/#{document.id}/inference", inference_update, auth_headers(user)
        expect(last_response.status).to eq(201)
        expect(document.document_inferences.count).to eq(5)
      end
    end
  end
end
