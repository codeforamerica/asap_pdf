class AddDepartment < ActiveRecord::Migration[8.0]
  def change
    add_column :documents, :department, :text
  end
end
