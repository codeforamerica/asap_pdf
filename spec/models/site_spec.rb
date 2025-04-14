require "rails_helper"

RSpec.describe Site, type: :model do
  subject { build(:site) }
  let(:user) { create(:user, site: user) }

  it { is_expected.to have_many(:users) }
  it { is_expected.to have_many(:documents) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:location) }
  it { is_expected.to validate_presence_of(:primary_url) }
  it { is_expected.to allow_value("http://example.com").for(:primary_url) }
  it { is_expected.not_to allow_value("invalid_url").for(:primary_url) }

  describe "S3 functionality" do
    describe "#s3_endpoint_prefix" do
      it "converts primary_url host to dasherized format" do
        site = build(:site, primary_url: "https://www.city.org")
        expect(site.s3_endpoint_prefix).to eq("www-city-org")
      end

      it "handles URLs with multiple subdomains" do
        site = build(:site, primary_url: "https://docs.sub.city.gov")
        expect(site.s3_endpoint_prefix).to eq("docs-sub-city-gov")
      end

      it "handles URLs with dashes" do
        site = build(:site, primary_url: "https://my-city.org")
        expect(site.s3_endpoint_prefix).to eq("my-city-org")
      end

      it "returns nil for blank URL" do
        site = build(:site, primary_url: nil)
        expect(site.s3_endpoint_prefix).to be_nil
      end
    end

    describe "#s3_endpoint" do
      it "combines S3_BUCKET with endpoint prefix" do
        site = build(:site, primary_url: "https://www.city.org")
        expect(site.s3_endpoint).to eq("s3://cfa-aistudio-asap-pdf/www-city-org")
      end

      it "returns nil for blank URL" do
        site = build(:site, primary_url: nil)
        expect(site.s3_endpoint).to be_nil
      end
    end

    describe "#s3_key_for" do
      it "combines endpoint prefix with filename" do
        site = build(:site, primary_url: "https://www.city.org")
        expect(site.s3_key_for("test.pdf")).to eq("www-city-org/test.pdf")
      end

      it "handles nested paths in filename" do
        site = build(:site, primary_url: "https://www.city.org")
        expect(site.s3_key_for("folder/test.pdf")).to eq("www-city-org/folder/test.pdf")
      end
    end
  end

  describe "#as_json" do
    let(:site) { create(:site, primary_url: "https://www.city.org") }

    it "excludes user_id, created_at, and updated_at" do
      json = site.as_json
      expect(json.keys).not_to include("user_id", "created_at", "updated_at")
    end

    it "includes s3_endpoint" do
      json = site.as_json
      expect(json["s3_endpoint"]).to eq("s3://cfa-aistudio-asap-pdf/www-city-org")
    end

    it "includes basic attributes" do
      json = site.as_json
      expect(json).to include(
        "id" => site.id,
        "name" => site.name,
        "location" => site.location,
        "primary_url" => site.primary_url
      )
    end
  end
end
