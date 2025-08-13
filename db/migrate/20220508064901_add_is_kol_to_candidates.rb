class AddIsKolToCandidates < ActiveRecord::Migration[6.0]
  def change
    add_column :candidates, :is_kol, :boolean, default: false
    add_column :candidates, :coef, :decimal, precision: 4, scale: 2, default: 0
  end
end
