require "rails_helper"

RSpec.describe Document, type: :model do
  it { should belong_to(:site) }

  describe "#file_name" do
    let(:document) { Document.new(document_category: "Brochure") }
    it { should validate_presence_of(:file_name) }
    it "handles file names with special characters" do
      document.file_name = "%C3%81fidos_GrowGreen_web.pdf"
      expect(document.file_name).to eq("Áfidos_GrowGreen_web.pdf")
    end
  end

  describe "#url" do
    let(:document) { Document.new(document_category: "Brochure") }
    it { should validate_presence_of(:url) }
    it { should allow_value("http://example.com").for(:url) }
    it { should_not allow_value("invalid-url").for(:url) }
    it "handles urls with special characters" do
      document.url = "https://www.austintexas.gov/growgreen/%25C3%2581fidos_GrowGreen_web.pdf"
      expect(document.normalized_url).to eq("https://www.austintexas.gov/growgreen/%C3%81fidos_GrowGreen_web.pdf")
      document.url = "https://www.slcdocs.com/Planning/Online Open Houses/2023/07_2023/PLNPCM2023-00223/2023.06.30 HH General Plan amendment narrative updated.pdf"
      expect(document.normalized_url).to eq("https://www.slcdocs.com/Planning/Online%20Open%20Houses/2023/07_2023/PLNPCM2023-00223/2023.06.30%20HH%20General%20Plan%20amendment%20narrative%20updated.pdf")
      document.url = "https://www.slcdocs.com/building/January%20Report%202025.pdf"
      expect(document.normalized_url).to eq("https://www.slcdocs.com/building/January%20Report%202025.pdf")
      document.url = "https://www.slcdocs.com%5Crecorder%5CEO_Disclosures%5CD4_Eva_Lopez_Chavez_2025Dislosure.pdf"
      expect(document.normalized_url).to eq("https://www.slcdocs.com/recorder/EO_Disclosures/D4_Eva_Lopez_Chavez_2025Dislosure.pdf")
      document.url = "https://www.slcdocs.com/Planning/Online+Open+Houses/2023/07_2023/PLNPCM2023-00482/SIDWELL+PARCEL+MAP+%282%29.pdf"
      expect(document.normalized_url).to eq("https://www.slcdocs.com/Planning/Online%20Open%20Houses/2023/07_2023/PLNPCM2023-00482/SIDWELL%20PARCEL%20MAP%20(2).pdf")
    end
    it "converts insecure urls to https" do
      document.url = "http://www.austintexas.gov/growgreen/%25C3%2581fidos_GrowGreen_web.pdf"
      expect(document.normalized_url).to eq("https://www.austintexas.gov/growgreen/%C3%81fidos_GrowGreen_web.pdf")
    end
    it "handles file names with special characters" do
      document.file_name = "view.email.slc.gov/?qs=2bca265e4e7cdcffef943d1a6e4f925c2716f253f48efdb9187c729aead8a3241d8ae450e7eed856670cbc8c1c34f9a20ee722d3622dc04e3063fbdd469cad49e8c0711ec6141dc715a0a5605ffcf561"
      expect(document.file_name).to eq("view.email.slc.govqs=2bca265e4e7cdcffef943d1a6e4f925c2716f253f48efdb9187c729aead8a3241d8ae450e7eed856670cbc8c1c34f9a20ee722d3622dc04e3063fbdd469cad49e8c0711ec6141dc715a0a5605ffcf561")
    end
  end

  it { should validate_inclusion_of(:document_status).in_array(%w[Active Removed New]) }
  it "defaults document_status to discovered" do
    expect(Document.new.document_status).to eq("Active")
  end

  describe "#primary_source" do
    let(:document) { Document.new(document_category: "Brochure") }

    it "returns nil when source is nil" do
      document.source = nil
      expect(document.primary_source).to be_nil
    end

    it "returns first URL when source is an array" do
      document.source = ["http://first.com", "http://second.com"]
      expect(document.primary_source).to eq("http://first.com")
    end

    it "returns source when it's not an array" do
      document.source = "http://single.com"
      expect(document.primary_source).to eq("http://single.com")
    end
  end

  describe "S3 storage" do
    let(:site) { create(:site, primary_url: "https://www.city.org") }
    let(:document) { Document.new(document_category: "Brochure", site: site) }

    describe "#s3_path" do
      it "generates correct path using site prefix and document id" do
        expect(document.s3_path).to eq("www-city-org/#{document.id}/document.pdf")
      end
    end
  end

  describe "#complexity" do
    let(:simple_document) { create(:document, document_category: "Brochure") }
    let(:complex_document) { create(:document, document_category: "Form") }
    let(:complex_document_images) { create(:document, document_category: "Brochure", number_of_images: 2) }
    let(:complex_document_tables) { create(:document, document_category: "Brochure", number_of_tables: 7) }

    it "is flagged as simple when not a form and there are no tables or images" do
      expect(simple_document.complexity).to eq(Document::SIMPLE_STATUS)
      simple_document.number_of_tables = 47
      simple_document.save
      expect(simple_document.complexity).to eq(Document::COMPLEX_STATUS)
    end
    it "is flagged as complex when it is a form" do
      expect(complex_document.complexity).to eq(Document::COMPLEX_STATUS)
      expect(complex_document_images.complexity).to eq(Document::COMPLEX_STATUS)
      expect(complex_document_tables.complexity).to eq(Document::COMPLEX_STATUS)
    end
  end
end
