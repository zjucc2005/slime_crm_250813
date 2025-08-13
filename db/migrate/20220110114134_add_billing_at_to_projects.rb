class AddBillingAtToProjects < ActiveRecord::Migration[6.0]
  def change
    add_column :projects, :billing_at, :datetime
    add_column :projects, :billed_at, :datetime
  end
end
