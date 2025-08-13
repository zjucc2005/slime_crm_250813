class AddKwlistToHospitals < ActiveRecord::Migration[6.0]
  def change
    add_column :hospitals, :kwlist, :jsonb, default: []
    remove_column :hospitals, :alias
  end
end
