class AddCategoryToCallRecords < ActiveRecord::Migration[6.0]
  def change
    add_column :call_records, :category, :string
    add_column :call_records, :project_requirement_id, :bigint
  end
end
