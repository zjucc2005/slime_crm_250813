class AddFile1ToProjectRequirements < ActiveRecord::Migration[6.0]
  def change
    add_column :project_requirements, :file1, :string
    add_column :project_requirements, :file2, :string
  end
end
