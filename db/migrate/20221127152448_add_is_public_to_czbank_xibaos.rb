class AddIsPublicToCzbankXibaos < ActiveRecord::Migration[6.0]
  def change
    add_column :czbank_xibaos, :is_public, :boolean, default: false
  end
end
