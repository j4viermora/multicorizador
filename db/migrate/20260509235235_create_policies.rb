class CreatePolicies < ActiveRecord::Migration[8.0]
  def change
    create_table :policies do |t|
      t.references :quote_result, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true
      t.string :policy_number, null: false
      t.string :status, default: "active", null: false
      t.datetime :issued_at
      t.date :starts_at
      t.date :ends_at
      t.monetize :premium, default: 0
      t.monetize :total, default: 0
      t.monetize :provider_commission, default: 0
      t.monetize :platform_commission, default: 0
      t.monetize :producer_commission, default: 0
      t.string :producer_commission_status, default: "pending", null: false
      t.datetime :producer_commission_paid_at
      t.json :webhook_payload, default: {}

      t.timestamps
    end

    add_index :policies, :policy_number
  end
end
