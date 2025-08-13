class CreateHospitalDepartments < ActiveRecord::Migration[6.0]
  def change
    create_table :hospital_departments do |t|
      t.references :hospital
      t.string :name
      t.timestamps :null => false
    end
  end
end
