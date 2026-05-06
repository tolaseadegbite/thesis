class AddEditorialColumns < ActiveRecord::Migration[8.1]
  def change
    add_column :theses, :fact_review_completed, :boolean, default: false, null: false
    add_column :extracted_facts, :selected, :boolean, default: false, null: false
  end
end
