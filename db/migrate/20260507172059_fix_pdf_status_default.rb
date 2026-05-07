class FixPdfStatusDefault < ActiveRecord::Migration[8.1]
  def change
    # 1. Update existing NULLs to 0 so the enum can map them
    Thesis.where(pdf_status: nil).update_all(pdf_status: 0)

    # 2. Add the default and null constraint to match your 'status' column
    change_column_default :theses, :pdf_status, from: nil, to: 0
    change_column_null :theses, :pdf_status, false, 0
  end
end
