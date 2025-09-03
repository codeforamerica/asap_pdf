class AddLlmDetailsDocumentInference < ActiveRecord::Migration[8.0]
  def change
    add_column :document_inferences, :inference_model_name, :string
    add_column :document_inferences, :token_details, :json
  end
end
