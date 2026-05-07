class AddVerificationDepthToTheses < ActiveRecord::Migration[8.1]
  def change
    add_column :theses, :verification_depth, :string, default: "moderate"
  end
end
