class Remove < ActiveRecord::Migration[8.0]
  def up
    remove_column :documents, :summary
  end

  def down
    add_column :documents, :summary, :text
  end
end
