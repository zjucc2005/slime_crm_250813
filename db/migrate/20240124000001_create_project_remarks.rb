class CreateProjectRemarks < ActiveRecord::Migration[6.0]
  def change
    create_table :project_remarks do |t|
      t.references :project, foreign_key: true
      t.text :remark
      t.timestamps null: false
    end
  end
end