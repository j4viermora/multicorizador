class CreateCommissionContracts < ActiveRecord::Migration[8.0]
  def change
    create_table :commission_contracts do |t|
      t.references :provider, null: false, foreign_key: true
      t.references :producer, null: true, foreign_key: { to_table: :users }
      t.decimal :provider_commission_rate, precision: 5, scale: 4, null: false
      t.decimal :producer_share_rate, precision: 5, scale: 4, null: false
      t.date :valid_from, null: false
      t.date :valid_until

      t.timestamps
    end

    add_index :commission_contracts, [:provider_id, :producer_id], unique: true, where: "producer_id IS NOT NULL", name: "index_commission_contracts_on_provider_and_producer"
    add_index :commission_contracts, :provider_id, unique: true, where: "producer_id IS NULL", name: "index_commission_contracts_default"
  end
end
