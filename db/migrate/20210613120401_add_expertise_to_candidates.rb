class AddExpertiseToCandidates < ActiveRecord::Migration[6.0]
  def change
    add_column :candidates, :expertise, :text
    add_column :candidates, :inquiry,   :integer
  end
end
