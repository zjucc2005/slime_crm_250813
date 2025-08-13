class AddGroupToCardTemplates < ActiveRecord::Migration[6.0]
  def change
    add_column :card_templates, :group, :string
  end
end
