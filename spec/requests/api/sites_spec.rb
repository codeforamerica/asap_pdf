require "rails_helper"

RSpec.describe AsapPdf::API do
  include Rack::Test::Methods

  def app
    AsapPdf::API
  end

  def headers(user)
    { HTTP_AUTHORIZATION: ActionController::HttpAuthentication::Basic.encode_credentials(user.email_address, user.password) }
  end
  def auth_get(user, route, params = {})
    get route, params: params, headers: headers(user)
  end

  describe "GET /sites" do
    let!(:sites) { create_list(:site, 3) }
    let!(:user) { create(:user, :admin) }

    it "blocks access to anonymous users" do
      get "/sites"
      expect(last_response.status).to eq(401)
    end

    it "returns all sites" do
      user = User.last
      p credentials_header_for(user)
      auth_get user, "/sites"
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body).length).to eq(3)
    end

    it "returns sites with correct structure" do
      user = User.last
      auth_get user, "/sites"
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

  describe "GET /sites/:id" do
    let!(:site) { create(:site) }

    context "when the site exists" do
      it "returns the requested site" do
        get "/sites/#{site.id}"
        expect(last_response.status).to eq(200)

        json_response = JSON.parse(last_response.body)
        expect(json_response["id"]).to eq(site.id)
        expect(json_response["name"]).to eq(site.name)
        expect(json_response["location"]).to eq(site.location)
        expect(json_response["primary_url"]).to eq(site.primary_url)
      end
    end

    context "when the site does not exist" do
      it "returns 404 not found" do
        get "/sites/0"
        expect(last_response.status).to eq(404)
      end
    end
  end

  describe "POST /sites/:id/documents" do
    let!(:site) { create(:site) }
    let(:timestamp) { Time.current }
    let(:valid_documents) do
      [
        {url: "https://example.com/doc1.pdf", modification_date: timestamp, document_category: "Brochure"},
        {url: "https://example.com/doc2.pdf", modification_date: timestamp, document_category: "Brochure"}
      ]
    end

    context "when the site exists" do
      it "creates new documents for new URLs" do
        expect {
          post "/sites/#{site.id}/documents", {documents: valid_documents}
        }.to change(Document, :count).by(2)

        expect(last_response.status).to eq(201)

        json_response = JSON.parse(last_response.body)
        expect(json_response["documents"].length).to eq(2)

        first_doc = json_response["documents"].first
        expect(first_doc).to include(
          "id",
          "url",
          "document_status",
          "s3_path"
        )
        expect(first_doc["url"]).to eq(valid_documents.first[:url])
        expect(first_doc["document_status"]).to eq("discovered")
        expect(first_doc["s3_path"]).to include(site.s3_endpoint_prefix)
      end

      it "updates existing documents when modification_date changes" do
        existing_doc = site.documents.create!(
          url: valid_documents.first[:url],
          modification_date: 1.day.ago,
          file_name: "doc1.pdf",
          document_status: "discovered",
          document_category: "Brochure"
        )

        expect {
          post "/sites/#{site.id}/documents", {documents: valid_documents}
        }.to change(Document, :count).by(1) # Only creates one new document

        expect(last_response.status).to eq(201)

        existing_doc.reload
        expect(existing_doc.document_status).to eq("discovered")
        expect(existing_doc.modification_date).to be_within(1.second).of(timestamp)
      end

      it "doesn't modify existing documents when modification_date hasn't changed" do
        existing_doc = site.documents.create!(
          url: valid_documents.first[:url],
          modification_date: timestamp,
          file_name: "doc1.pdf",
          document_status: "discovered",
          document_category: "Brochure"
        )

        expect {
          post "/sites/#{site.id}/documents", {documents: valid_documents}
        }.to change(Document, :count).by(1) # Only creates one new document

        expect(last_response.status).to eq(201)

        existing_doc.reload
        expect(existing_doc.document_status).to eq("discovered")
      end
    end

    context "when the site does not exist" do
      it "returns 404 not found" do
        post "/sites/0/documents", {documents: valid_documents}
        expect(last_response.status).to eq(404)
      end
    end

    context "with invalid parameters" do
      it "returns 400 bad request when documents is missing" do
        post "/sites/#{site.id}/documents"
        expect(last_response.status).to eq(400)
      end

      it "returns 400 bad request when documents is not an array" do
        post "/sites/#{site.id}/documents", {documents: "not_an_array"}
        expect(last_response.status).to eq(400)
      end

      it "returns 400 bad request when document is missing required fields" do
        post "/sites/#{site.id}/documents", {documents: [{url: "https://example.com/doc.pdf"}]}
        expect(last_response.status).to eq(400)
      end
    end
  end
end
