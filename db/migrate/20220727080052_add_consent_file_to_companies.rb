class AddConsentFileToCompanies < ActiveRecord::Migration[6.0]
  def change
    add_column :companies, :consent_file, :string
    add_column :companies, :consent_file_options, :jsonb, default: {}
  end
end
