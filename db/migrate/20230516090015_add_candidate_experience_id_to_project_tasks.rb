class AddCandidateExperienceIdToProjectTasks < ActiveRecord::Migration[6.0]
  def change
    add_column :project_tasks, :candidate_experience_id, :bigint
  end
end
