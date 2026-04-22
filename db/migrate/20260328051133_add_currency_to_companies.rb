class AddCurrencyToCompanies < ActiveRecord::Migration[8.0]
  def change
    add_column :companies, :currency, :string, null: false, default: "USD"
  end
end
