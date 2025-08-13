class AddDocumentInferenceActiveFlag < ActiveRecord::Migration[8.0]
  def up
    add_column :document_inferences, :is_active, :boolean
    remove_index :document_inferences, [:document_id, :inference_type]
  end

  def down
    remove_column :document_inferences, :is_active
  end
end
