class CreateDocumentInferences < ActiveRecord::Migration[8.0]
  def change
    create_table :document_inferences do |t|
      t.datetime :creation_date
      t.references :document, null: false, foreign_key: true
      t.text :inference_type
      t.text :inference_value
      t.float :inference_confidence
      t.text :inference_reason
    end
  end
end
