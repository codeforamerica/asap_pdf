require "rails_helper"

describe "documents function as expected", js: true, type: :feature do
  before :each do
    @current_user = User.create(email_address: "user@example.com", password: "password1231231232wordpass")
    login_user(@current_user)
  end

  it "documents belong to a site and may be manipulated" do
    # Create our test setup
    site = Site.create(name: "City of Denver", location: "Colorado", primary_url: "https://denvergov.org")
    @current_user.site = site
    @current_user.save!
    denver_doc = Document.create(url: "http://denvergov.org/docs/example.pdf", file_name: "example.pdf", document_category: "Agenda", accessibility_recommendation: Document::DEFAULT_ACCESSIBILITY_RECOMMENDATION, site: site)
    site = Site.create(name: "City of Boulder", location: "Colorado", primary_url: "https://bouldercolorado.gov")
    boulder_user = User.create(email_address: "boulder@example.com", password: "password1231231232wordpass", site: site)
    rtd_contract_doc = Document.create(url: "https://bouldercolorado.gov/docs/rtd_contract.pdf", file_name: "rtd_contract.pdf", document_category: "Agreement", document_category_confidence: 0.73, accessibility_recommendation: Document::DEFAULT_ACCESSIBILITY_RECOMMENDATION, site: site)
    teahouse_doc = Document.create(url: "https://bouldercolorado.gov/docs/teahouse_rules.pdf", file_name: "teahouse_rules.pdf", document_category: "Notice", document_category_confidence: 0.71, accessibility_recommendation: Document::DEFAULT_ACCESSIBILITY_RECOMMENDATION, site: site, modification_date: "2024-10-01")
    Document.create(url: "https://bouldercolorado.gov/docs/farmers_market_2023.pdf", file_name: "farmers_market_2023.pdf", document_category: "Notice", accessibility_recommendation: Document::DEFAULT_ACCESSIBILITY_RECOMMENDATION, site: site, modification_date: "2024-10-01")
    # Test single document and document editing.
    visit "/"
    click_link("City of Denver")
    expect(page).to have_selector("#document-list", visible: true, wait: 5)
    within("#document-list") do
      expect(page).to have_content "Colorado: City of Denver"
      expect(page).to have_no_content "No documents found"
      expect(page).to have_content "example.pdf\nAgenda\nNeeds Decision\nNo notes"
      expect(page).to have_no_content "rtd_contract.pdf"
      expect(page).not_to have_selector "[data-text-edit-field-value='notes'] textarea"
      notes = find("[data-text-edit-field-value='notes']")
      notes.click
      sleep(1)
      textarea = notes.find("textarea")
      textarea.send_keys("Fee fi fo fum")
      textarea.send_keys(:enter)
      expect(page).not_to have_selector "[data-dropdown-edit-field-value='accessibility_recommendation'] select"
      decision = find("[data-dropdown-edit-field-value='accessibility_recommendation']")
      decision.click
      select = decision.find("select")
      select.find("[value='Convert']").click
      denver_doc.status = "Audit Done"
      denver_doc.save
    end
    visit "/"
    click_link("City of Denver")
    within("#document-list") do
      expect(page).to have_content "No documents found"
    end
    within("#sidebar") do
      click_link "Audit Done"
    end
    within("#document-list") do
      expect(page).to have_no_content "No documents found"
      expect(page).to have_content "example.pdf\nAgenda\nConvert\nFee fi fo fum"
    end
    within("#sidebar") do
      expect(page).to have_content "Backlog\n0"
      expect(page).to have_content "In Review\n0"
      expect(page).to have_content "Audit Done\n1"
    end
    Session.last.destroy
    login_user(boulder_user)
    # Test multiple documents and filtration.
    visit "/"
    click_link("City of Boulder")
    within("#document-list") do
      expect(page).to have_content "Colorado: City of Boulder"
      expect(page).to have_no_content "No documents found"
      expect(page).to have_css("tbody tr", count: 3)
    end
    within("#sidebar") do
      fill_in id: "start_date", with: "10/01/2024"
      fill_in id: "end_date", with: "10/31/2024"
      fill_in id: "filename", with: "farmers_market_2023.pdf"
      find("#category").find("[value='Notice']").click
      click_button "Apply Filters"
    end
    within("#document-list") do
      expect(page).to have_css("tbody tr", count: 1)
      expect(page).to have_content "farmers_market_2023.pdf"
      expect(page).to have_no_content "rtd_contract.pdf"
    end
    within("#sidebar") do
      click_link "Clear"
      sleep(1)
    end
    within("#document-list") do
      expect(page).to have_css("tbody tr", count: 3)
      # Test decision filter.
      decision = find("tr:nth-child(1) [data-dropdown-edit-field-value='accessibility_recommendation']")
      decision.click
      select = decision.find("select")
      select.find("[value='Convert']").click
    end
    within("#sidebar") do
      find("#accessibility_recommendation").find("[value='Remediate']").click
      click_button "Apply Filters"
    end
    within("#document-list") do
      expect(page).to have_content "No documents found"
      expect(page).to have_no_content "farmers_market_2023.pdf"
    end
    within("#sidebar") do
      find("#accessibility_recommendation").find("[value='Convert']").click
      click_button "Apply Filters"
    end
    within("#document-list") do
      expect(page).to have_no_content "No documents found"
      expect(page).to have_css("tbody tr", count: 1)
      expect(page).to have_content "farmers_market_2023.pdf"
    end
    # Test department filter.
    within("#sidebar") do
      expect(page).to have_no_content "Department"
      expect(page).to have_no_selector "#department"
    end
    rtd_contract_doc.department = "Department of Public Transportation"
    rtd_contract_doc.save!
    teahouse_doc.department = "Office of Rose-laden Beverages"
    teahouse_doc.save!
    visit "/"
    click_link("City of Boulder")
    within("#sidebar") do
      expect(page).to have_selector "#department"
      expect(page).to have_selector "#department option[value='None']"
      expect(page).to have_selector "#department option[value='Office of Rose-laden Beverages']"
      find("#department option[value='None']").click
      click_button "Apply Filters"
    end
    within("#document-list") do
      expect(page).to have_no_content "teahouse_rules.pdf"
      expect(page).to have_no_content "rtd_contract.pdf"
      expect(page).to have_content "farmers_market_2023.pdf"
    end
    within("#sidebar") do
      find("#department option[value='']").click
      click_button "Apply Filters"
    end
    within("#document-list") do
      expect(page).to have_content "teahouse_rules.pdf"
      expect(page).to have_content "rtd_contract.pdf"
      expect(page).to have_content "farmers_market_2023.pdf"
    end
    # Test complexity filter.
    within("#sidebar") do
      expect(page).to have_no_content "Complexity"
      expect(page).to have_no_content "#complexity"
    end
    rtd_contract_doc.complexity = Document::SIMPLE_STATUS
    rtd_contract_doc.save!
    teahouse_doc.complexity = Document::COMPLEX_STATUS
    teahouse_doc.save!
    visit "/"
    click_link("City of Boulder")
    within("#sidebar") do
      expect(page).to have_selector "#complexity"
      expect(page).to have_selector "#complexity option[value='Simple']"
      expect(page).to have_selector "#complexity option[value='Complex']"
      find("#complexity option[value='']").click
      click_button "Apply Filters"
    end
    within("#document-list") do
      expect(page).to have_content "teahouse_rules.pdf"
      expect(page).to have_content "rtd_contract.pdf"
      expect(page).to have_content "farmers_market_2023.pdf"
    end
    within("#sidebar") do
      find("#complexity option[value='Simple']").click
      click_button "Apply Filters"
    end
    within("#document-list") do
      expect(page).to have_no_content "teahouse_rules.pdf"
      expect(page).to have_no_content "farmers_market_2023.pdf"
      expect(page).to have_content "rtd_contract.pdf"
    end
    # Test sorting
    within("#sidebar") do
      click_link "Clear"
      find("#category").find("[value='Notice']").click
      click_button "Apply Filters"
    end
    within("#document-list thead") do
      click_link "Type"
    end
    expect(page).to have_no_content "rtd_contract.pdf", wait: 2
    within("#document-list tbody tr:nth-child(1)") do
      expect(page).to have_content "teahouse_rules.pdf"
    end
    within("#document-list tbody tr:nth-child(2)") do
      expect(page).to have_content "farmers_market_2023.pdf"
    end
    # Make sure sorting doesn't get cleared.
    within("#sidebar") do
      click_link "Clear"
    end
    within("#document-list tbody tr:nth-child(1)") do
      expect(page).to have_content "teahouse_rules.pdf"
    end
    within("#document-list tbody tr:nth-child(2)") do
      expect(page).to have_content "rtd_contract.pdf"
    end
    within("#document-list tbody tr:nth-child(3)") do
      expect(page).to have_content "farmers_market_2023.pdf"
    end
    # Test sort and filter interplay.
    within("#sidebar") do
      find("#category").find("[value='Notice']").click
      click_button "Apply Filters"
    end
    expect(page).to have_no_content "rtd_contract.pdf", wait: 2
    within("#document-list thead") do
      click_link "Type"
    end
    expect(page).to have_no_content "rtd_contract.pdf", wait: 2
    within("#document-list tbody tr:nth-child(2)") do
      expect(page).to have_content "teahouse_rules.pdf"
    end
    within("#document-list tbody tr:nth-child(1)") do
      expect(page).to have_content "farmers_market_2023.pdf"
    end
    within("#sidebar") do
      fill_in id: "start_date", with: "10/01/2024"
      click_button "Apply Filters"
    end
    expect(page).to have_no_content "rtd_contract.pdf", wait: 2
    within("#document-list tbody tr:nth-child(2)") do
      expect(page).to have_content "teahouse_rules.pdf"
    end
    within("#document-list tbody tr:nth-child(1)") do
      expect(page).to have_content "farmers_market_2023.pdf"
    end
  end

  it "documents have some tabs" do
    # Create our test setup
    site = Site.create(name: "City of Denver", location: "Colorado", primary_url: "https://denvergov.org")
    @current_user.site = site
    @current_user.save!
    doc = Document.create(url: "http://denvergov.org/docs/ex.ample.pdf", file_name: "ex.ample.pdf", document_category: "Agenda", accessibility_recommendation: Document::DEFAULT_ACCESSIBILITY_RECOMMENDATION, site_id: site.id)
    iframe_src = serve_file_content_document_path(doc.id, doc.file_name) + "?pagemode=none&toolbar=1"
    visit "/"
    click_link("City of Denver")
    # Test out the modal and tabs.
    within("#document-list") do
      click_button "ex.ample.pdf"
    end
    # Wait for modal to open.
    expect(page).to have_selector("#document-list .modal", visible: true, wait: 5)
    within("#document-list .modal") do
      # Assess default tab.
      expect(page).to have_content "ex.ample.pdf"
      expect(page).to have_css("[data-action='modal#showSummaryView'].tab-active")
      # Later we'll check to see if the button is gone.
      expect(page).to have_content "Summarize Document"
      expect(page).to have_css("iframe[src='#{iframe_src}']")
      # Check out "PDF Details" tab.
      click_button "PDF Details"
      expect(page).to have_no_css("[data-action='modal#showSummaryView'].tab-active")
      expect(page).to have_css("[data-action='modal#showMetadataView'].tab-active")
      expect(page).to have_no_css("iframe[src='#{iframe_src}']")
      expect(page).to have_content "File Name\nex.ample.pdf"
      expect(page).to have_content "Type\nAgenda"
      expect(page).to have_content "Decision\nNeeds Decision"
      # Add a note.
      notes = find("[data-controller='modal-notes'] textarea")
      notes.send_keys("Fee fi fo fum")
      click_button "Update Notes"
    end
    # Prep the doc so we can assess the summary space.
    # Note the extra quotes necessary for our string escaping.
    DocumentInference.new(document_id: doc.id, inference_type: "summary", inference_value: '"A lovely example of accessible PDF practices."').save
    # Check out "History" tab and look for notes.
    visit "/"
    click_link("City of Denver")
    within("#document-list") do
      click_button "ex.ample.pdf"
    end
    expect(page).to have_selector("#document-list .modal", visible: true, wait: 5)
    within("#document-list .modal") do
      click_button "History"
      expect(page).to have_content("Notes: blank → Fee fi fo fum")
      expect(page).to have_content("Document category: blank → Agenda")
      # Check for the summary we updated above.
      click_button "Summary"
      expect(page).to have_content("A lovely example of accessible PDF practices.")
      expect(page).to have_no_content "Summarize Document"
      # Test for the recommendation tab.
      click_button "AI Exception Check"
      expect(page).to have_content("Get AI Exception Check")
      expect(page).to have_no_content "This suggestion was generated by a Large Language Model and while highly reliable, should still be subjected to careful verification."
    end
    # Add some inferences.
    DocumentInference.create(inference_type: "exception:is_application", inference_value: "True", inference_reason: "This is not used as an application or means of participation in government services.", document_id: doc.id)
    DocumentInference.create(inference_type: "exception:is_third_party", inference_value: "False", inference_reason: "This is not third party.", document_id: doc.id)
    visit "/"
    click_link("City of Denver")
    within("#document-list") do
      click_button "ex.ample.pdf"
    end
    expect(page).to have_selector("#document-list .modal", visible: true, wait: 5)
    within("#document-list .modal") do
      click_button "AI Exception Check"
      expect(page).to have_no_content("Get AI Exception Check")
      expect(page).to have_content("This suggestion was generated by a Large Language Model and while highly reliable, should still be subjected to careful verification.")
      expect(page).to have_content("AI Exception Check\nMight be exception")
      expect(page).to have_content("Preexisting documents: Yes\nThis is not used as an application or means of participation in government services.")
      expect(page).to have_content("Third party content: No\nThis is not third party.")
      find(".close").click
    end
  end

  it "updates documents in bulk" do
    # Create our test setup
    site = Site.create(name: "City of Boulder", location: "Colorado", primary_url: "https://bouldercolorado.gov")
    @current_user.site = site
    @current_user.save!
    Document.create(url: "https://bouldercolorado.gov/docs/rtd_contract.pdf", file_name: "rtd_contract.pdf", document_category: "Agreement", document_category_confidence: 0.73, accessibility_recommendation: Document::DEFAULT_ACCESSIBILITY_RECOMMENDATION, site: site)
    Document.create(url: "https://bouldercolorado.gov/docs/teahouse_rules.pdf", file_name: "teahouse_rules.pdf", document_category: "Notice", document_category_confidence: 0.71, accessibility_recommendation: Document::DEFAULT_ACCESSIBILITY_RECOMMENDATION, site: site)
    Document.create(url: "https://bouldercolorado.gov/docs/farmers_market_2023.pdf", file_name: "farmers_market_2023.pdf", document_category: "Notice", accessibility_recommendation: Document::DEFAULT_ACCESSIBILITY_RECOMMENDATION, site: site, modification_date: "2024-10-01")
    visit "/"
    click_link("City of Boulder")
    # Check for a default state.
    within("#sidebar") do
      expect(page).to have_content "Audit Backlog\n3"
      expect(page).to have_content "In Review\n0"
      expect(page).to have_content "Audit Done\n0"
    end
    within("#document-list") do
      expect(page).to have_content "rtd_contract.pdf\nAgreement\n73%\nNeeds Decision"
      expect(page).to have_content "teahouse_rules.pdf\nNotice\n71%\nNeeds Decision"
      expect(page).to have_content "farmers_market_2023.pdf\nOct 01, 2024\nNotice\nNeeds Decision"
      expect(page).to have_no_css("#bulk_edit_control", visible: true)
      # Try checking a box.
      find("tr:nth-child(1) [data-bulk-edit-target='selectOne']").check
    end
    within("#bulk_edit_control") do
      expect(page).to have_content "Selected: 1"
      # Try clicking the "x".
      find("[data-action='bulk-edit#handleCloseActions']").click
      expect(page).to have_no_css("#bulk_edit_control", visible: true)
    end
    within("#document-list") do
      checkbox = find("tr:nth-child(1) [data-bulk-edit-target='selectOne']")
      expect(checkbox).not_to be_checked
      # Try the select all.
      find("th:nth-child(1) [data-bulk-edit-target='selectAll']").check
    end
    within("#bulk_edit_control") do
      expect(page).to have_content "Selected: 3"
      select = find("#bulk-edit-move")
      select.find("[value='In Review']").click
    end
    within("#bulk_edit_modal") do
      expect(page).to have_content "Confirm move"
      expect(page).to have_content 'You are about to move 3 documents to "In Review".'
      click_button "Cancel"
    end
    expect(page).to have_no_selector("#bulk_edit_modal", visible: true)
    within("#bulk_edit_control") do
      select = find("#bulk-edit-move")
      select.find("[value='In Review']").click
    end
    within("#bulk_edit_modal") do
      click_button "Confirm"
    end
    within("#document-list") do
      expect(page).to have_content "No documents found"
    end
    within("#sidebar") do
      expect(page).to have_content "Audit Backlog\n0"
      expect(page).to have_content "In Review\n3"
      expect(page).to have_content "Audit Done\n0"
      visit "/sites/#{site.id}/documents?status=In+Review"
    end
    within("#document-list") do
      expect(page).to have_content "rtd_contract.pdf\nAgreement\n73%\nNeeds Decision"
      expect(page).to have_content "teahouse_rules.pdf\nNotice\n71%\nNeeds Decision"
      expect(page).to have_content "farmers_market_2023.pdf\nOct 01, 2024\nNotice\nNeeds Decision"
      # Try checking a box.
      find("tr:nth-child(1) [data-bulk-edit-target='selectOne']").check
    end
    within("#bulk_edit_control") do
      select = find("#bulk-edit-move")
      select.find("[value='Audit Done']").click
    end
    within("#bulk_edit_modal") do
      click_button "Confirm"
    end
    within("#sidebar") do
      expect(page).to have_content "Audit Backlog\n0"
      expect(page).to have_content "In Review\n2"
      expect(page).to have_content "Audit Done\n1"
    end
  end
  it "insights may be had" do
    # Create our test setup
    site = Site.create(name: "City of Boulder", location: "Colorado", primary_url: "https://bouldercolorado.gov")
    @current_user.site = site
    @current_user.save!
    Document.create(url: "https://bouldercolorado.gov/docs/rtd_contract.pdf",
      file_name: "rtd_contract.pdf",
      document_category: "Agreement",
      document_category_confidence: 0.73,
      accessibility_recommendation: Document::DEFAULT_ACCESSIBILITY_RECOMMENDATION,
      department: "Public Transportation",
      complexity: "Simple",
      site: site,
      creation_date: "2022-10-01",
      modification_date:  "2022-10-01")
    Document.create(url: "https://bouldercolorado.gov/docs/teahouse_rules.pdf",
      file_name: "teahouse_rules.pdf",
      document_category: "Notice",
      document_category_confidence: 0.71,
      accessibility_recommendation: Document::DEFAULT_ACCESSIBILITY_RECOMMENDATION,
      department: "The Earl Gray Team",
      complexity: "Complex",
      site: site,
      creation_date: "2022-10-01",
      modification_date:  "2023-10-01")
    Document.create(url: "https://bouldercolorado.gov/docs/farmers_market_2023.pdf",
      file_name: "farmers_market_2023.pdf",
      document_category: "Notice",
      accessibility_recommendation: Document::DEFAULT_ACCESSIBILITY_RECOMMENDATION,
      department: "Parks and Recreation",
      complexity: "Complex",
      site: site,
      creation_date: "2022-10-01",
      modification_date: "2024-10-01")
    visit "/"
    click_link "City of Boulder"
    within("#document-list #document-tabs") do
      click_link "Insights"
      sleep(1)
    end
    # Look for general content.
    within("#insights") do
      expect(page).to have_content "Colorado: City of Boulder"
      expect(page).to have_content "Document Complexity"
      expect(page).to have_content "Document Last Modified Year"
      expect(page).to have_content "Decision"
      expect(page).to have_content "\nTYPE AUDIT BACKLOG IN REVIEW AUDIT DONE TOTAL\nAgreement 1 0 0 1\nNotice 2 0 0 2"
    end
    # Test filters.
    within("#sidebar") do
      expect(page).to have_content "Audit Backlog\n3"
      expect(page).to have_content "In Review\n0"
      expect(page).to have_content "Audit Done\n0"
      find("#category option[value='Agreement']").click
      find("#department option[value='Public Transportation']").click
      find("#status option[value='Audit Backlog']").click
      click_button "Apply Filters"
    end
    sleep(1)
    assert_match "sites/#{site.id}/insights?category=Agreement&department=Public+Transportation&status=Audit+Backlog", current_url
    # Look for general content.
    within("#insights") do
      expect(page).to have_content "\nTYPE AUDIT BACKLOG IN REVIEW AUDIT DONE TOTAL\nAgreement 1 0 0 1"
      expect(page).to have_no_content "\nNotice 2 0 0 2"
    end
    # Test following document links.
    within("#insights #chart-complexity") do
      find(".dropdown .btn").click
      click_link "Complex"
    end
    sleep(1)
    assert_match "sites/#{site.id}/documents?category=Agreement&commit=Apply+Filters&complexity=Complex&department=Public+Transportation&status=Audit+Backlog", current_url
    visit "/sites/#{site.id}/insights?category=Agreement&department=Public+Transportation&status=Audit+Backlog"
    within("#insights #chart-modification-year") do
      find(".dropdown .btn").click
      click_link "2018-2023"
    end
    sleep(1)
    assert_match "sites/#{site.id}/documents?category=Agreement&department=Public+Transportation&end_date=2023-12-31&start_date=2018-01-01&status=Audit+Backlog", current_url
    visit "/sites/#{site.id}/insights?category=Agreement&department=Public+Transportation&status=Audit+Backlog"
    within("#insights #chart-decision") do
      find(".dropdown .btn").click
      click_link "Needs Decision"
    end
    sleep(1)
    assert_match "sites/#{site.id}/documents?accessibility_recommendation=Needs+Decision&category=Agreement&department=Public+Transportation&status=Audit+Backlog", current_url
  end
end
