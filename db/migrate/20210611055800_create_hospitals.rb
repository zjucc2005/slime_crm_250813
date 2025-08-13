class CreateHospitals < ActiveRecord::Migration[6.0]
  def change
    create_table :hospitals do |t|
      t.string :name
      t.string :province
      t.string :level
      t.timestamps :null => false
    end
  end
end
