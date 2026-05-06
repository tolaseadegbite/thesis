class AddSubsectionsToChapters < ActiveRecord::Migration[8.1]
  def change
    add_column :chapters, :subsections, :jsonb
  end
end
