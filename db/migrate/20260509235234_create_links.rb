class CreateLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :links do |t|
      t.references :company, null: false, foreign_key: true
      t.references :quote, null: false, foreign_key: true
      t.string :token, null: false
      t.string :purpose, default: "quote_share", null: false
      t.datetime :expires_at
      t.integer :access_count, default: 0, null: false
      t.datetime :last_accessed_at
      t.string :status, default: "active", null: false

      t.timestamps
    end

    add_index :links, :token, unique: true
  end
end
