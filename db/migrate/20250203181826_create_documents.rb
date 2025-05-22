class CreateDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :documents do |t|
      t.text :file_name
      t.text :url
      t.integer :file_size
      t.text :source
      t.string :status
      t.string :document_status, default: "discovered"
      t.string :document_category, default: "Unknown"
      t.float :document_category_confidence
      t.text :accessibility_recommendation, default: Document::DEFAULT_DECISION
      t.float :accessibility_confidence
      t.text :title
      t.text :author
      t.text :subject
      t.text :keywords
      t.datetime :creation_date
      t.datetime :modification_date
      t.text :producer
      t.text :pdf_version
      t.integer :number_of_pages
      t.text :notes
      t.text :summary

      t.references :site, null: false, foreign_key: true

      t.timestamps
    end
  end
end
