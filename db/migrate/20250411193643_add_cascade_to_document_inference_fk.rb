class AddCascadeToDocumentInferenceFk < ActiveRecord::Migration[8.0]
  def up
    remove_foreign_key :document_inferences, :documents
    add_foreign_key :document_inferences, :documents, on_delete: :cascade
  end

  def down
    remove_foreign_key :document_inferences, :documents
    add_foreign_key :document_inferences, :documents
  end
end
