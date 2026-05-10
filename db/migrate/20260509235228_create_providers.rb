class CreateProviders < ActiveRecord::Migration[8.0]
  def change
    create_table :providers do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :status, default: "active", null: false
      t.json :config, default: {}

      t.timestamps
    end

    add_index :providers, :slug, unique: true
  end
end
