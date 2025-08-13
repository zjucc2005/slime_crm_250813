class AddInvoiceFileToPrepaidClients < ActiveRecord::Migration[6.0]
  def change
    add_column :prepaid_clients, :invoice_file, :string
  end
end