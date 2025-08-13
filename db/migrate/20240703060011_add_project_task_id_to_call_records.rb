class AddProjectTaskIdToCallRecords < ActiveRecord::Migration[6.0]
  def change
    add_column :call_records, :project_task_id, :bigint
  end
end
