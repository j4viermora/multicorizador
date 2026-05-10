class CreateProducerInvoicePolicies < ActiveRecord::Migration[8.0]
  def change
    create_table :producer_invoice_policies do |t|
      t.references :producer_invoice, null: false, foreign_key: true
      t.references :policy, null: false, foreign_key: true

      t.timestamps
    end

    add_index :producer_invoice_policies, [:producer_invoice_id, :policy_id], unique: true
  end
end
