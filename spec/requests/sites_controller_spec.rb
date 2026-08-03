require "rails_helper"

RSpec.describe SitesController, type: :request do
  include Warden::Test::Helpers

  describe "GET workflow_audit_report" do
    let(:site) { create(:site) }
    let(:bucket_name) { Rails.application.config.default_s3_bucket }
    let(:file_key) { "reports/#{site.machine_name}/audit.csv" }
    let(:file_content) { "id,name,status\n1,doc1,complete" }

    let(:s3_response) do
      {
        body: StringIO.new(file_content),
        content_type: "text/csv"
      }
    end

    let(:s3_manager) { instance_double(AwsS3Manager) }

    before do
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

      it "serves a file under its own site's prefix" do
        get workflow_audit_report_site_path(site, bucket_name: bucket_name, key: file_key)

        expect(response).to have_http_status(:ok)
        expect(response.body).to eq(file_content)
      end

      it "refuses a non-default bucket without hitting S3" do
        expect(s3_manager).not_to receive(:get_object!)

        get workflow_audit_report_site_path(site, bucket_name: "some-other-bucket", key: file_key)

        expect(response).to have_http_status(:not_found)
      end

      it "refuses a key under another site's prefix" do
        other_site = create(:site)

        get workflow_audit_report_site_path(site, bucket_name: bucket_name, key: "reports/#{other_site.machine_name}/audit.csv")

        expect(response).to have_http_status(:not_found)
      end

      it "refuses a key outside any reports prefix" do
        get workflow_audit_report_site_path(site, bucket_name: bucket_name, key: "secrets/credentials.csv")

        expect(response).to have_http_status(:not_found)
      end

      it "enforces the trailing-slash boundary against sibling prefixes" do
        revenue = create(:site, name: "Revenue")
        revenue_user = create(:user, site: revenue)
        login_as(revenue_user, scope: :user)

        # "revenue" is a prefix of "revenue_dept" — must not be readable.
        get workflow_audit_report_site_path(revenue, bucket_name: bucket_name, key: "reports/revenue_dept/audit.csv")

        expect(response).to have_http_status(:not_found)
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
        expect(response.body).to include("You don&#39;t have permission to access that site.")
      end
    end

    context "as unauthenticated user" do
      it "returns unauthorized" do
        get workflow_audit_report_site_path(site, bucket_name: bucket_name, key: file_key)

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST create_workflow_audit_report" do
    let(:site) { create(:site) }

    after { Warden.test_reset! }

    # Request specs carry no CSRF token; disable forgery protection for this
    # spec only so the POST reaches the authorization check instead of being
    # rejected with a 422 first.
    around do |example|
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = false
      example.run
      ActionController::Base.allow_forgery_protection = original
    end

    context "as a non-admin assigned to a different site" do
      let(:other_site) { create(:site) }
      let(:user) { create(:user, site: other_site) }

      before { login_as(user, scope: :user) }

      it "refuses to generate a report for a site the user cannot access" do
        expect_any_instance_of(Site).not_to receive(:export_document_audit!)

        post create_workflow_audit_report_site_path(site)

        expect(response).to redirect_to(sites_path)
        follow_redirect!
        expect(response.body).to include("You don&#39;t have permission to access that site.")
      end
    end
  end
end
