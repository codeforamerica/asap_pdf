class RemoveStatusColumn < ActiveRecord::Migration[8.0]
  def up
    remove_column :documents, :status
  end

  def down
    add_column :documents, :status, :string
  end
end
