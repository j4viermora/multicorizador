class CreateProducerInvoices < ActiveRecord::Migration[8.0]
  def change
    create_table :producer_invoices do |t|
      t.references :company, null: false, foreign_key: true
      t.references :producer, null: false, foreign_key: { to_table: :users }
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.monetize :total_commission, default: 0
      t.string :status, default: "draft", null: false
      t.datetime :paid_at

      t.timestamps
    end
  end
end
