require "rails_helper"

RSpec.describe Document, type: :model do
  it { should belong_to(:site) }

  describe "#file_name" do
    let(:document) { Document.new }
    it { should validate_presence_of(:file_name) }
    it "handles file names with special characters" do
      document.file_name = "%C3%81fidos_GrowGreen_web.pdf"
      expect(document.file_name).to eq("Áfidos_GrowGreen_web.pdf")
    end
  end

  describe "#url" do
    let(:document) { Document.new }
    it { should validate_presence_of(:url) }
    it { should allow_value("http://example.com").for(:url) }
    it { should_not allow_value("invalid-url").for(:url) }
    it "handles urls with special characters" do
      document.url = "https://www.austintexas.gov/growgreen/%25C3%2581fidos_GrowGreen_web.pdf"
      expect(document.url).to eq("https://www.austintexas.gov/growgreen/%C3%81fidos_GrowGreen_web.pdf")
    end
    it "converts insecure urls to https" do
      document.url = "http://www.austintexas.gov/growgreen/%25C3%2581fidos_GrowGreen_web.pdf"
      expect(document.url).to eq("https://www.austintexas.gov/growgreen/%C3%81fidos_GrowGreen_web.pdf")
    end
  end

  it { should validate_inclusion_of(:document_status).in_array(%w[discovered downloaded]) }
  it "defaults document_status to discovered" do
    expect(Document.new.document_status).to eq("discovered")
  end

  describe "#primary_source" do
    let(:document) { Document.new }

    it "returns nil when source is nil" do
      document.source = nil
      expect(document.primary_source).to be_nil
    end

    it "returns first URL when source is an array" do
      document.source = ["http://first.com", "http://second.com"]
      expect(document.primary_source).to eq("http://first.com")
    end

    it "returns source when it's not an array" do
      document.source = "http://single.com"
      expect(document.primary_source).to eq("http://single.com")
    end
  end

  describe "S3 storage" do
    let(:site) { create(:site, primary_url: "https://www.city.org") }
    let(:document) { create(:document, site: site) }

    describe "#s3_path" do
      it "generates correct path using site prefix and document id" do
        expect(document.s3_path).to eq("www-city-org/#{document.id}/document.pdf")
      end
    end

    # describe "versioning", :aws do
    #   let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }
    #   let(:s3_resource) { Aws::S3::Resource.new(client: s3_client) }

    #   before do
    #     allow(Aws::S3::Resource).to receive(:new).and_return(s3_resource)
    #   end

    #   before do
    #     allow(Rails.application.config.active_storage).to receive(:service_configurations)
    #       .and_return({
    #         Rails.env.to_s => {
    #           "service" => "S3",
    #           "access_key_id" => "test",
    #           "secret_access_key" => "test",
    #           "region" => "us-east-1",
    #           "bucket" => "test-bucket",
    #           "endpoint" => "http://localhost:4566",
    #           "force_path_style" => true
    #         }
    #       })
    #   end

    #   describe "#file_versions" do
    #     it "returns list of versions" do
    #       versions = [
    #         double("version1", version_id: "v1", modification_date: Time.current, size: 1000, etag: "abc"),
    #         double("version2", version_id: "v2", modification_date: 1.day.ago, size: 900, etag: "def")
    #       ]

    #       allow_any_instance_of(Aws::S3::Bucket).to receive(:object_versions)
    #         .with(prefix: document.s3_path)
    #         .and_return(versions)

    #       expect(document.file_versions.count).to eq(2)
    #     end
    #   end

    #   describe "#latest_file" do
    #     it "returns the most recent version" do
    #       latest = double("latest_version", version_id: "v1", modification_date: Time.current)
    #       older = double("older_version", version_id: "v2", modification_date: 1.day.ago)

    #       allow_any_instance_of(Aws::S3::Bucket).to receive(:object_versions)
    #         .with(prefix: document.s3_path)
    #         .and_return([latest, older])

    #       expect(document.latest_file).to eq(latest)
    #     end
    #   end

    #   describe "#file_version" do
    #     it "gets specific version by id" do
    #       version = double("version")
    #       allow_any_instance_of(Aws::S3::Object).to receive(:get)
    #         .with(version_id: "v1")
    #         .and_return(version)

    #       expect(document.file_version("v1")).to eq(version)
    #     end
    #   end

    #   describe "#version_metadata" do
    #     it "returns formatted version metadata" do
    #       time = Time.current
    #       version = double(
    #         "version",
    #         version_id: "v1",
    #         modification_date: time,
    #         size: 1000,
    #         etag: "abc123"
    #       )

    #       metadata = document.version_metadata(version)

    #       expect(metadata).to include(
    #         version_id: "v1",
    #         modification_date: time,
    #         size: 1000,
    #         etag: "abc123"
    #       )
    #     end
    #   end
    # end
  end
end
