class AddCoefIndexToCandidates < ActiveRecord::Migration[6.0]
  def change
    add_index :candidates, :coef
  end
end
