class AddPdfFieldsToTheses < ActiveRecord::Migration[8.1]
  def change
    add_column :theses, :pdf_status, :integer
  end
end
