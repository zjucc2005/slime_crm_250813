class AddIsYibaoToCandidates < ActiveRecord::Migration[6.0]
  def change
    add_column :candidates, :is_yibao, :boolean, default: false
  end
end
