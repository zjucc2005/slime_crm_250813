class AddCityToHospitals < ActiveRecord::Migration[6.0]
  def change
    add_column :hospitals, :city, :string
    add_column :hospitals, :alias, :string
  end
end
