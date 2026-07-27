require "rails_helper"

RSpec.describe FeedbackItemsController, type: :request do
  include Warden::Test::Helpers

  after { Warden.test_reset! }

  # Request specs carry no CSRF token, so disable forgery protection for this
  # spec only. Turning it off globally would strip the csrf-token meta tag that
  # the app's JS depends on, breaking the JS feature specs.
  around do |example|
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = false
    example.run
    ActionController::Base.allow_forgery_protection = original
  end

  let(:site) { create(:site) }
  let(:document) { create(:document, site: site) }
  let(:inference) { create(:document_inference, document: document) }
  let(:user) { create(:user, site: site) }

  describe "authentication" do
    it "returns 401 for an unauthenticated PATCH" do
      patch update_feedback_items_feedback_items_path,
        params: {feedback_items: [{document_inference_id: inference.id, sentiment: "positive"}]},
        as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(FeedbackItem.count).to eq(0)
    end

    it "returns 401 for an unauthenticated DELETE" do
      create(:feedback_item, document_inference: inference, user: user)

      delete delete_items_feedback_items_path,
        params: {feedback_items: [{document_inference_id: inference.id}]},
        as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(FeedbackItem.count).to eq(1)
    end
  end

  describe "PATCH update_feedback_items" do
    before { login_as(user, scope: :user) }

    it "creates feedback owned by the current user" do
      patch update_feedback_items_feedback_items_path,
        params: {feedback_items: [{document_inference_id: inference.id, sentiment: "negative", comment: "off"}]},
        as: :json

      expect(response).to have_http_status(:ok)
      item = FeedbackItem.sole
      expect(item.user).to eq(user)
      expect(item.sentiment).to eq("negative")
    end

    it "ignores a body user_id that names another user" do
      other_user = create(:user, site: site)

      patch update_feedback_items_feedback_items_path,
        params: {feedback_items: [{document_inference_id: inference.id, user_id: other_user.id, sentiment: "positive"}]},
        as: :json

      expect(response).to have_http_status(:ok)
      expect(FeedbackItem.sole.user).to eq(user)
    end

    it "refuses feedback on an inference belonging to another site" do
      other_inference = create(:document_inference, document: create(:document, site: create(:site)))

      patch update_feedback_items_feedback_items_path,
        params: {feedback_items: [{document_inference_id: other_inference.id, sentiment: "positive"}]},
        as: :json

      expect(response).to have_http_status(:not_found)
      expect(FeedbackItem.count).to eq(0)
    end

    it "lets a site admin leave feedback across sites" do
      admin = create(:user, :site_admin)
      login_as(admin, scope: :user)
      other_inference = create(:document_inference, document: create(:document, site: create(:site)))

      patch update_feedback_items_feedback_items_path,
        params: {feedback_items: [{document_inference_id: other_inference.id, sentiment: "positive"}]},
        as: :json

      expect(response).to have_http_status(:ok)
      expect(FeedbackItem.sole.user).to eq(admin)
    end
  end

  describe "DELETE delete_items" do
    before { login_as(user, scope: :user) }

    it "removes only the caller's own feedback" do
      mine = create(:feedback_item, document_inference: inference, user: user)
      theirs = create(:feedback_item, document_inference: inference, user: create(:user, site: site))

      delete delete_items_feedback_items_path,
        params: {feedback_items: [{document_inference_id: inference.id}]},
        as: :json

      expect(response).to have_http_status(:no_content)
      expect(FeedbackItem.exists?(mine.id)).to be(false)
      expect(FeedbackItem.exists?(theirs.id)).to be(true)
    end

    it "refuses to act on an inference belonging to another site" do
      other_site = create(:site)
      other_inference = create(:document_inference, document: create(:document, site: other_site))
      row = create(:feedback_item, document_inference: other_inference, user: user)

      delete delete_items_feedback_items_path,
        params: {feedback_items: [{document_inference_id: other_inference.id}]},
        as: :json

      expect(response).to have_http_status(:not_found)
      expect(FeedbackItem.exists?(row.id)).to be(true)
    end
  end
end
