class CreateExtractedFacts < ActiveRecord::Migration[8.1]
  def change
    create_table :extracted_facts do |t|
      t.references :thesis, null: false, foreign_key: true
      t.references :paper, null: false, foreign_key: true
      t.text :evidence_text
      t.integer :page_number
      t.float :confidence

      t.timestamps
    end
  end
end
