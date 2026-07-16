class AddSoldViaToPolicies < ActiveRecord::Migration[8.0]
  def change
    add_column :policies, :sold_via, :string, null: false, default: "direct"
    add_index :policies, :sold_via
  end
end
