class AddBelongDateToCzbankXibaos < ActiveRecord::Migration[6.0]
  def change
    add_column :czbank_xibaos, :belong_date, :datetime
  end
end
