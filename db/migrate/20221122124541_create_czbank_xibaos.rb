class CreateCzbankXibaos < ActiveRecord::Migration[6.0]
  def change
    create_table :czbank_xibaos do |t|
      t.string :cod_id
      t.string :org_name
      t.string :staff_name
      t.string :staff_id
      t.integer :sale_value
      t.datetime :trans_date
      t.integer :bill_count
      t.integer :dl_count, default: 0
      t.timestamps null: false
    end
  end
end
