class AddRecStatusToCallRecords < ActiveRecord::Migration[6.0]
  def change
    add_column :call_records, :rec_status, :string
    add_column :call_records, :rec_description, :string
  end
end
