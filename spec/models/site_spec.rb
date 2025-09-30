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
end
