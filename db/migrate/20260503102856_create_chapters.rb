class CreateChapters < ActiveRecord::Migration[8.1]
  def change
    create_table :chapters do |t|
      t.references :thesis, null: false, foreign_key: true
      t.string :title
      t.integer :order
      t.integer :status, default: 0
      t.text :markdown_content

      t.timestamps
    end
  end
end
