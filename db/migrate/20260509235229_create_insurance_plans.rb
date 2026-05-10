class CreateInsurancePlans < ActiveRecord::Migration[8.0]
  def change
    create_table :insurance_plans do |t|
      t.references :provider, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.json :coverage_details, default: {}
      t.string :status, default: "active", null: false

      t.timestamps
    end
  end
end
