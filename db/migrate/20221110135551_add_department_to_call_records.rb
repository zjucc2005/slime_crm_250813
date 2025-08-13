class AddDepartmentToCallRecords < ActiveRecord::Migration[6.0]
  def change
    add_column :call_records, :department, :string
  end
end
