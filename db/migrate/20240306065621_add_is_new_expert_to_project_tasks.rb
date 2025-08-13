class AddIsNewExpertToProjectTasks < ActiveRecord::Migration[6.0]
  def change
    add_column :project_tasks, :is_new_expert, :boolean, default: false
  end
end
