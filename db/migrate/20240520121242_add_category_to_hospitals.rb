class AddCategoryToHospitals < ActiveRecord::Migration[6.0]
  def change
    add_column :hospitals, :category, :string
  end
end
