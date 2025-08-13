class AddLijinToProjectTaskCosts < ActiveRecord::Migration[6.0]
  def change
    add_column :project_task_costs, :lijin, :decimal, precision: 10, scale: 2
  end
end
