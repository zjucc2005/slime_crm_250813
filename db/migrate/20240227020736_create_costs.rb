class CreateCosts < ActiveRecord::Migration[6.0]
  def change
    create_table :cost_summaries do |t|
      t.datetime :datetime
      t.decimal :price, precision: 10, scale: 2
      t.bigint :operator_id
      t.timestamps null: false
    end

    create_table :costs do |t|
      t.references :cost_summary
      t.references :cost_type
      t.string :name
      t.decimal :price, precision: 10, scale: 2
      t.string :remark
      t.timestamps null: false
    end
  end
end
