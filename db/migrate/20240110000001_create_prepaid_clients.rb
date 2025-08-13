class CreatePrepaidClients < ActiveRecord::Migration[6.0]
  def change
    create_table :prepaid_clients do |t|
      t.references :company, null: false, foreign_key: true
      t.references :contract, null: false, foreign_key: true
      t.decimal :total_hours, null: false, default: 0
      t.decimal :used_hours, null: false, default: 0
      t.decimal :invoice_amount, null: false, default: 0
      t.datetime :invoice_date
      t.string :invoice_number
      t.date :expected_payment_date

      t.timestamps
    end
  end
end