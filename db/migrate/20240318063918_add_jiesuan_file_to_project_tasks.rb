class AddJiesuanFileToProjectTasks < ActiveRecord::Migration[6.0]
  def change
    add_column :project_tasks, :jiesuan_file, :string
  end
end
