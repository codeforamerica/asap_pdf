class CreateFeedbackItems < ActiveRecord::Migration[8.0]
  def change
    create_table :feedback_items do |t|
      t.datetime :creation_date
      t.datetime :modification_date
      t.text :sentiment
      t.text :comment
      t.references :document_inference, null: true, foreign_key: {on_delete: :cascade}
      t.references :user, null: true
    end
  end

  def rollback
    drop_table :feedback_items
  end
end
