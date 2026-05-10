class ChangeDefaultCurrency < ActiveRecord::Migration[8.0]
  def up
    change_column_default :companies, :currency, from: "USD", to: "ARS"
    Company.where(currency: "USD").update_all(currency: "ARS")
  end

  def down
    change_column_default :companies, :currency, from: "ARS", to: "USD"
    Company.where(currency: "ARS").update_all(currency: "USD")
  end
end
