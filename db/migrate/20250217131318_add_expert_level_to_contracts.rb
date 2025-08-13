class AddExpertLevelToContracts < ActiveRecord::Migration[6.0]
  def change
    add_column :contracts, :expert_level, :string
  end
end
