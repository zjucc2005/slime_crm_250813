class CreateCallRecords < ActiveRecord::Migration[6.0]
  def change
    create_table :call_records do |t|
      t.string :name
      t.string :company
      t.string :title
      t.string :phone
      t.integer :number_of_calls
      t.string :status
      t.string :memo
      t.bigint :created_by
      t.bigint :operator_id
      t.bigint :user_channel_id
      t.references :project
      t.references :candidate

      t.timestamps :null => false
    end
  end
end
