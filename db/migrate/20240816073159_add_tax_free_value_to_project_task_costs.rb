class AddTaxFreeValueToProjectTaskCosts < ActiveRecord::Migration[6.0]
  def change
    add_column :project_task_costs, :tax_free_value, :decimal, precision: 10, scale: 2, default: 0
  end
end
