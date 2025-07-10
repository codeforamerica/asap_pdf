require "rails_helper"

RSpec.describe SessionsController, type: :controller do
  let(:user) { User.create!(email: "test@example.com", password: "password") }

  describe "GET #new" do
    it "returns http success" do
      get :new
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST #create" do
    context "with valid credentials" do
      it "creates a new session" do
        expect {
          post :create, params: {email: user.email, password: "password"}
        }.to change(Session, :count).by(1)
      end

      it "redirects to root path" do
        post :create, params: {email: user.email, password: "password"}
        expect(response).to redirect_to(root_path)
      end
    end

    context "with invalid credentials" do
      it "does not create a session" do
        expect {
          post :create, params: {email: user.email, password: "wrong"}
        }.not_to change(Session, :count)
      end

      it "renders new template" do
        post :create, params: {email: user.email, password: "wrong"}
        expect(response).to render_template(:new)
      end
    end
  end

  describe "DELETE #destroy" do
    let!(:session) { user.sessions.create! }

    before do
      Current.session = session
      cookies.signed.permanent[:session_id] = {value: session.id, httponly: true, same_site: :lax}
    end

    it "destroys the session" do
      expect {
        delete :destroy
      }.to change(Session, :count).by(-1)
    end

    it "redirects to login path" do
      delete :destroy
      expect(response).to redirect_to(login_path)
    end

    it "clears the session cookie" do
      delete :destroy
      expect(cookies.signed[:session_id]).to be_nil
    end
  end
end
