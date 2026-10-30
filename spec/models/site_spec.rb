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

  describe "#machine_name" do
    it "lowercases the name and collapses non-word runs into underscores" do
      expect(build(:site, name: "SLC.gov").machine_name).to eq("slc_gov")
    end
  end

  describe "report-identifier uniqueness" do
    it "rejects a second site whose name resolves to the same machine_name" do
      create(:site, name: "SLC Gov")
      dup = build(:site, name: "SLC.gov")
      expect(dup).not_to be_valid
      expect(dup.errors[:name]).to be_present
    end
  end
end
