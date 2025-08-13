class AddFileToCandidates < ActiveRecord::Migration[6.0]
  def change
    add_column :candidates, :file, :string
  end
end
