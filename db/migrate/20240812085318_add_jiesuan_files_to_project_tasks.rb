class AddJiesuanFilesToProjectTasks < ActiveRecord::Migration[6.0]
  def change
    add_column :project_tasks, :jiesuan_files, :jsonb, default: []
  end
end
