class CreateProjectMarks < ActiveRecord::Migration[6.0]
  def change
    create_table :project_marks do |t|
      t.string :mark_type
      t.references :project
      t.references :user

      t.timestamps
    end
    add_index :project_marks, [:user_id, :project_id], unique: true, name: 'index_project_marks_on_user_project'

  end
end
