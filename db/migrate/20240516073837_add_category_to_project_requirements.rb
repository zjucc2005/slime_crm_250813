class AddCategoryToProjectRequirements < ActiveRecord::Migration[6.0]
  def change
    add_column :project_requirements, :category, :string
    add_column :project_requirements, :priority, :integer, default: 0
  end
end
