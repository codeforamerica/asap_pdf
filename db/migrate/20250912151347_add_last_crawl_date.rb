class AddLastCrawlDate < ActiveRecord::Migration[8.0]
  def up
    add_column :documents, :last_crawl_date, :datetime
  end

  def down
    remove_column :documents, :last_crawl_date
  end
end
