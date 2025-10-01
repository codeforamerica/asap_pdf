class AddLastCrawlDate < ActiveRecord::Migration[8.0]
  def up
    add_column :documents, :last_crawl_date, :datetime
    change_column_default :documents, :document_status, from: nil, to: Document::DOCUMENT_STATUS_ACTIVE
  end

  def down
    remove_column :documents, :last_crawl_date
    change_column_default :documents, :document_status, from: Document::DOCUMENT_STATUS_ACTIVE, to: nil
  end
end
