class AddAdvancePaymentHoursToPrepaidClients < ActiveRecord::Migration[6.0]
  def change
    add_column :prepaid_clients, :advance_payment_hours, :decimal, precision: 10, scale: 3, default: 0
  end
end
