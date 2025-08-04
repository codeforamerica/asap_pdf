class AddInvitationFlag < ActiveRecord::Migration[8.0]
  def change
    change_table :users do |t|
      t.boolean :is_invited
    end
  end
end
