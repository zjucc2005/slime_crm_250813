class AddCategory2ToCandidates < ActiveRecord::Migration[6.0]
  def change
    add_column :candidates, :category2, :string
    add_column :candidate_experiences, :org_id, :bigint
    add_column :candidate_experiences, :dep_id, :bigint
    add_index :candidate_experiences, :org_id
    add_index :candidate_experiences, :dep_id
  end
end
