class CreateQuoteResults < ActiveRecord::Migration[8.0]
  def change
    create_table :quote_results do |t|
      t.references :quote, null: false, foreign_key: true
      t.references :provider, null: false, foreign_key: true
      t.references :insurance_plan, null: true, foreign_key: true
      t.string :external_quote_id
      t.json :raw_response, default: {}
      t.string :status, default: "pending", null: false
      t.monetize :price, default: 0
      t.monetize :provider_commission, default: 0
      t.monetize :platform_commission, default: 0
      t.monetize :producer_commission, default: 0

      t.timestamps
    end
  end
end
