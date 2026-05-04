class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      t.references :chapter, null: false, foreign_key: true
      t.references :fact, foreign_key: { to_table: :extracted_facts }
      t.string :action
      t.text :old_text
      t.text :new_text
      t.text :professor_notes

      t.timestamps
    end
  end
end
