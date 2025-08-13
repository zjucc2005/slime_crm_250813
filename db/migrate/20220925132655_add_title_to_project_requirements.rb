class AddTitleToProjectRequirements < ActiveRecord::Migration[6.0]
  def change
    add_column :project_requirements, :title, :string
  end
end
