class AddStatusMessageToChapters < ActiveRecord::Migration[8.1]
  def change
    add_column :chapters, :status_message, :string
  end
end
