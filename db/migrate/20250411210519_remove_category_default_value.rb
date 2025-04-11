class RemoveCategoryDefaultValue < ActiveRecord::Migration[8.0]
  def change
    change_column_default(:documents, :document_category, nil)
    change_column_null :documents, :document_category, false
  end
end
