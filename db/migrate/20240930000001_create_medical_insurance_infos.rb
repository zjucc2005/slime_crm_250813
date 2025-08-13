class CreateMedicalInsuranceInfos < ActiveRecord::Migration[6.0]
  def change
    create_table :medical_insurance_infos do |t|
      t.references :candidate, null: false, foreign_key: true
      t.integer :year, null: false
      t.boolean :is_clinical, default: false
      t.string :non_clinical_type # 非临床时的分类：测算组/综合组
      t.string :sub_type # 子分类
      
      t.timestamps
    end
    
    add_index :medical_insurance_infos, [:candidate_id, :year], unique: true
  end
end