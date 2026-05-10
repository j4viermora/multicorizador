class CreatePlatformInvoices < ActiveRecord::Migration[8.0]
  def change
    create_table :platform_invoices do |t|
      t.references :provider, null: false, foreign_key: true
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.monetize :total_commission, default: 0
      t.string :status, default: "draft", null: false
      t.datetime :paid_at

      t.timestamps
    end
  end
end
