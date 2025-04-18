class AddImageAndTableCounts < ActiveRecord::Migration[8.0]
  def change
    add_column :documents, :number_of_tables, :integer
    add_column :documents, :number_of_images, :integer
  end
end
