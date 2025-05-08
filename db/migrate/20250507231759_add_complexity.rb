class AddComplexity < ActiveRecord::Migration[8.0]
  def change
    add_column :documents, :complexity, :text
  end
end
