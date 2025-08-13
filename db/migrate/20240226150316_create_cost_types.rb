class CreateCostTypes < ActiveRecord::Migration[6.0]
  def change
    create_table :cost_types do |t|
      t.string :name
      t.string :path
      t.integer :parent_id
      t.boolean :is_parent, default: false
      t.boolean :disabled, default: false
      t.timestamps null: false
    end
  end
end
