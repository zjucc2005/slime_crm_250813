class CreateCTags < ActiveRecord::Migration[6.0]
  def change
    create_table :c_tags do |t|
      t.string :name
      t.string :path
      t.integer :parent_id
      t.boolean :is_parent, default: false
      t.boolean :disabled, default: false
      t.timestamps null: false
    end

    add_index :c_tags, :parent_id
  end
end
