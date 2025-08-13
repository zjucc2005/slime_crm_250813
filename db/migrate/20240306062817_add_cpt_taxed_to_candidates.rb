class AddCptTaxedToCandidates < ActiveRecord::Migration[6.0]
  def change
    add_column :candidates, :cpt_taxed, :boolean, default: true
  end
end
