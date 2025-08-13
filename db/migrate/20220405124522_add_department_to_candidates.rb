class AddDepartmentToCandidates < ActiveRecord::Migration[6.0]
  def change
    add_column :candidates, :department, :string
    add_column :candidates, :address, :string
  end
end
