class CreateCompanySummaries < ActiveRecord::Migration[6.0]
  def change
    create_table :company_summaries do |t|
      t.references :company
      t.datetime :datetime
      t.bigint :operator_id
      t.timestamps null: false
    end

    create_table :company_infos do |t|
      t.references :company_summary
      t.string :name
      t.decimal :price, precision: 10, scale: 2
      t.string :remark
      t.timestamps null: false
    end
  end
end
