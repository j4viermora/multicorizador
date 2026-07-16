class RemoveCommissionModel < ActiveRecord::Migration[8.0]
  def change
    drop_table :producer_invoice_policies do |t|
      t.integer "producer_invoice_id", null: false
      t.integer "policy_id", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
    end

    drop_table :producer_invoices do |t|
      t.integer "company_id", null: false
      t.integer "producer_id", null: false
      t.date "period_start", null: false
      t.date "period_end", null: false
      t.integer "total_commission_cents", default: 0, null: false
      t.string "total_commission_currency", default: "ARS", null: false
      t.string "status", default: "draft", null: false
      t.datetime "paid_at"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
    end

    drop_table :platform_invoices do |t|
      t.integer "provider_id", null: false
      t.date "period_start", null: false
      t.date "period_end", null: false
      t.integer "total_commission_cents", default: 0, null: false
      t.string "total_commission_currency", default: "ARS", null: false
      t.string "status", default: "draft", null: false
      t.datetime "paid_at"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
    end

    drop_table :commission_contracts do |t|
      t.integer "provider_id", null: false
      t.integer "producer_id"
      t.decimal "provider_commission_rate", precision: 5, scale: 4, null: false
      t.decimal "producer_share_rate", precision: 5, scale: 4, null: false
      t.date "valid_from", null: false
      t.date "valid_until"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
    end

    remove_column :quote_results, :provider_commission_cents, :integer, default: 0, null: false
    remove_column :quote_results, :provider_commission_currency, :string, default: "ARS", null: false
    remove_column :quote_results, :platform_commission_cents, :integer, default: 0, null: false
    remove_column :quote_results, :platform_commission_currency, :string, default: "ARS", null: false
    remove_column :quote_results, :producer_commission_cents, :integer, default: 0, null: false
    remove_column :quote_results, :producer_commission_currency, :string, default: "ARS", null: false

    remove_column :policies, :provider_commission_cents, :integer, default: 0, null: false
    remove_column :policies, :provider_commission_currency, :string, default: "ARS", null: false
    remove_column :policies, :platform_commission_cents, :integer, default: 0, null: false
    remove_column :policies, :platform_commission_currency, :string, default: "ARS", null: false
    remove_column :policies, :producer_commission_cents, :integer, default: 0, null: false
    remove_column :policies, :producer_commission_currency, :string, default: "ARS", null: false
    remove_column :policies, :producer_commission_status, :string, default: "pending", null: false
    remove_column :policies, :producer_commission_paid_at, :datetime
  end
end
