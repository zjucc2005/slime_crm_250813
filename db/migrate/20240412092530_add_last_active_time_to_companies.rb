class AddLastActiveTimeToCompanies < ActiveRecord::Migration[6.0]
  def change
    add_column :companies, :last_active_time, :datetime
  end
end
