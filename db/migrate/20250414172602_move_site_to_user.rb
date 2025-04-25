class MoveSiteToUser < ActiveRecord::Migration[8.0]
  def up
    # Remove user reference on site.
    remove_reference :sites, :user
    # Add site reference to user instead.
    add_reference :users, :site, null: true, foreign_key: true
  end

  def down
    # Reverse the above.
    remove_reference :users, :site
    add_reference :sites, :user, foreign_key: true
  end
end
