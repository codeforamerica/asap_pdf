require "rails_helper"

RSpec.describe User, type: :model do
  before do
    create(:user, email: "test@example.com")
  end

  it { is_expected.to belong_to(:site).optional(true) }
  it { is_expected.to delegate_method(:documents).to(:site).allow_nil }

  it { is_expected.to validate_presence_of(:email) }
  it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
  it { is_expected.to allow_value("user@example.com").for(:email) }
  it { is_expected.not_to allow_value("invalid_email").for(:email) }
end
