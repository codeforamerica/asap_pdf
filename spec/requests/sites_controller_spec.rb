require "rails_helper"

RSpec.describe SitesController, type: :request do
  include Warden::Test::Helpers

  describe "GET workflow_audit_report" do
    let(:site) { create(:site) }
    let(:bucket_name) { "test-bucket" }
    let(:file_key) { "reports/audit.csv" }
    let(:file_content) { "id,name,status\n1,doc1,complete" }

    let(:s3_response) do
      {
        body: StringIO.new(file_content),
        content_type: "text/csv"
      }
    end

    before do
      s3_manager = instance_double(AwsS3Manager)
      allow(AwsS3Manager).to receive(:new).and_return(s3_manager)
      allow(s3_manager).to receive(:get_object!).and_return(s3_response)
    end

    after { Warden.test_reset! }

    context "as admin" do
      let(:admin_user) { create(:user, :site_admin) }

      before { login_as(admin_user, scope: :user) }

      it "serves the file" do
        get workflow_audit_report_site_path(site, bucket_name: bucket_name, key: file_key)

        expect(response).to have_http_status(:ok)
        expect(response.body).to eq(file_content)
      end
    end

    context "as non-admin with site access" do
      let(:user) { create(:user, site: site) }

      before { login_as(user, scope: :user) }

      it "serves the file" do
        get workflow_audit_report_site_path(site, bucket_name: bucket_name, key: file_key)

        expect(response).to have_http_status(:ok)
        expect(response.body).to eq(file_content)
      end
    end

    context "as non-admin without site access" do
      let(:other_site) { create(:site) }
      let(:user) { create(:user, site: other_site) }

      before { login_as(user, scope: :user) }

      it "redirects with permission error" do
        get workflow_audit_report_site_path(site, bucket_name: bucket_name, key: file_key)

        expect(response).to redirect_to(sites_path)
        follow_redirect!
        expect(response.body).to include("You don't have permission to access that site.")
      end
    end

    context "as unauthenticated user" do
      it "returns unauthorized" do
        get workflow_audit_report_site_path(site, bucket_name: bucket_name, key: file_key)

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
