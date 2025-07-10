class DropSessionsTable < ActiveRecord::Migration[8.0]
  def change
    drop_table :sessions
  end
end
