class CreateTheses < ActiveRecord::Migration[8.1]
  def change
    create_table :theses do |t|
      t.text :topic
      t.integer :status, default: 0
      t.jsonb :outline, default: {}
      t.float :cost_estimate

      t.timestamps
    end
  end
end
