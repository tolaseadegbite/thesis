class CreatePapers < ActiveRecord::Migration[8.1]
  def change
    create_table :papers do |t|
      t.string :title
      t.string :url
      t.string :doi
      t.text :citation_apa
      t.text :abstract

      t.timestamps
    end
  end
end
