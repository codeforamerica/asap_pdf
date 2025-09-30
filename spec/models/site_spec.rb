require "rails_helper"

RSpec.describe Site, type: :model do
  subject { build(:site) }

  it { is_expected.to have_many(:users) }
  it { is_expected.to have_many(:documents) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:location) }
  it { is_expected.to validate_presence_of(:primary_url) }
  it { is_expected.to allow_value("http://example.com").for(:primary_url) }
  it { is_expected.not_to allow_value("invalid_url").for(:primary_url) }

  it { is_expected.to validate_uniqueness_of(:primary_url) }
  it { is_expected.to validate_uniqueness_of(:name) }

  describe "#as_json" do
    let(:site) { create(:site, primary_url: "https://www.city.org") }

    it "excludes user_id, created_at, and updated_at" do
      json = site.as_json
      expect(json.keys).not_to include("user_id", "created_at", "updated_at")
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
