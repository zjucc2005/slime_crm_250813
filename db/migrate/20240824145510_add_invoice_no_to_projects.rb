class AddInvoiceNoToProjects < ActiveRecord::Migration[6.0]
  def change
    add_column :projects, :invoice_no, :string
    add_column :projects, :invoice_payment_date, :datetime
    add_column :projects, :invoice_amount, :decimal, precision: 10, scale: 2
    add_column :projects, :invoice_file, :string
  end
end
