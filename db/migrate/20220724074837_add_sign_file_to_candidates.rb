class AddSignFileToCandidates < ActiveRecord::Migration[6.0]
  def change
    add_column :candidates, :sign_file, :string
  end
end
