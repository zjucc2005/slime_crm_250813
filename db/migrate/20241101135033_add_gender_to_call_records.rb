class AddGenderToCallRecords < ActiveRecord::Migration[6.0]
  def change
    add_column :call_records, :nickname, :string
    add_column :call_records, :gender, :string
    add_column :call_records, :title1, :string
    add_column :call_records, :academic_field, :string
    add_column :call_records, :remark, :string
    add_column :call_records, :memo_logs, :jsonb, :default => []
    add_column :call_records, :email, :string
    add_column :call_records, :city, :string
  end
end
