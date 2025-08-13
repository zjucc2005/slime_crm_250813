class CreateKpiSummaries < ActiveRecord::Migration[6.0]
  def change
    create_table :kpi_summaries do |t|
      t.references :user
      t.datetime :datetime
      t.bigint :operator_id
      t.timestamps null: false
    end

    create_table :kpi_infos do |t|
      t.references :kpi_summary
      t.string :name
      t.decimal :price, precision: 10, scale: 2
      t.string :remark
      t.timestamps null: false
    end
  end
end
