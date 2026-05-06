class AddTargetPaperCountToTheses < ActiveRecord::Migration[8.1]
  def change
    add_column :theses, :target_paper_count, :integer, default: 15, null: false
  end
end
