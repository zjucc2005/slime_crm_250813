class CreateSearchAliases < ActiveRecord::Migration[6.0]
  def change
    create_table :search_aliases do |t|
      t.string :name
      t.jsonb :kwlist, :default => []

      t.timestamps :null => false
    end
  end
end
