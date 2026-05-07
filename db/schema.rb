# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_06_183213) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audit_logs", force: :cascade do |t|
    t.string "action"
    t.bigint "chapter_id", null: false
    t.datetime "created_at", null: false
    t.bigint "fact_id"
    t.text "new_text"
    t.text "old_text"
    t.text "professor_notes"
    t.datetime "updated_at", null: false
    t.index ["chapter_id"], name: "index_audit_logs_on_chapter_id"
    t.index ["fact_id"], name: "index_audit_logs_on_fact_id"
  end

  create_table "chapters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "markdown_content"
    t.integer "order"
    t.integer "status", default: 0
    t.string "status_message"
    t.jsonb "subsections"
    t.bigint "thesis_id", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["thesis_id"], name: "index_chapters_on_thesis_id"
  end

  create_table "extracted_facts", force: :cascade do |t|
    t.float "confidence"
    t.datetime "created_at", null: false
    t.text "evidence_text"
    t.integer "page_number"
    t.bigint "paper_id", null: false
    t.boolean "selected", default: false, null: false
    t.bigint "thesis_id", null: false
    t.datetime "updated_at", null: false
    t.index ["paper_id"], name: "index_extracted_facts_on_paper_id"
    t.index ["thesis_id"], name: "index_extracted_facts_on_thesis_id"
  end

  create_table "papers", force: :cascade do |t|
    t.text "abstract"
    t.text "citation_apa"
    t.datetime "created_at", null: false
    t.string "doi"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url"
  end

  create_table "theses", force: :cascade do |t|
    t.float "cost_estimate"
    t.datetime "created_at", null: false
    t.boolean "fact_review_completed", default: false, null: false
    t.jsonb "outline", default: {}
    t.integer "status", default: 0
    t.integer "target_paper_count", default: 15, null: false
    t.text "topic"
    t.datetime "updated_at", null: false
    t.string "verification_depth", default: "moderate"
  end

  add_foreign_key "audit_logs", "chapters"
  add_foreign_key "audit_logs", "extracted_facts", column: "fact_id"
  add_foreign_key "chapters", "theses"
  add_foreign_key "extracted_facts", "papers"
  add_foreign_key "extracted_facts", "theses"
end
