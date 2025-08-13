class AddTitle1ToCandidateExperiences < ActiveRecord::Migration[6.0]
  def change
    add_column :candidate_experiences, :title1, :string
  end
end
