class ChangeAdminRoles < ActiveRecord::Migration[8.0]
  def change
    change_table :user do |t|
      rename_column :users, :is_admin, :is_site_admin
      add_column :users, :is_user_admin, :boolean
    end
  end
end
