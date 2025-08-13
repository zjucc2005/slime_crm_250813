class AddRecruitmentRateToContract < ActiveRecord::Migration[6.0]
  def change
    add_column :contracts, :recruitment_rate, :decimal, precision: 10, scale: 2
  end
end
