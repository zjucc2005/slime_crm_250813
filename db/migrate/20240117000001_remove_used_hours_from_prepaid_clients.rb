class RemoveUsedHoursFromPrepaidClients < ActiveRecord::Migration[6.0]
  def change
    remove_column :prepaid_clients, :used_hours, :decimal
  end
end