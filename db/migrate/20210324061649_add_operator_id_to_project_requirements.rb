class AddOperatorIdToProjectRequirements < ActiveRecord::Migration[6.0]
  def change
    add_column :project_requirements, :operator_id, :bigint
  end
end
