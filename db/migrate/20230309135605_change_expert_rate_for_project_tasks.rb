class ChangeExpertRateForProjectTasks < ActiveRecord::Migration[6.0]
  def up
    change_column :project_tasks, :expert_rate, :decimal, precision: 20, scale: 18
  end

  def down
    change_column :project_tasks, :expert_rate, :decimal, precision: 10, scale: 2
  end
end
