class AddUniqueKeyToDocumentInferences < ActiveRecord::Migration[8.0]
  def up
    remove_column :documents, :summary
  end

  def change
    add_index :document_inferences, [:document_id, :inference_type], unique: true
  end

  def down
    add_column :documents, :summary, :text
  end
end
