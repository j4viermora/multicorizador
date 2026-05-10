class CreateQuotes < ActiveRecord::Migration[8.0]
  def change
    create_table :quotes do |t|
      t.references :company, null: false, foreign_key: true
      t.references :producer, null: false, foreign_key: { to_table: :users }
      t.references :traveler, null: true, foreign_key: true
      t.string :status, default: "draft", null: false
      t.string :public_token
      t.string :origin, null: false
      t.string :destination, null: false
      t.date :departure_date, null: false
      t.date :return_date
      t.integer :travelers_count, default: 1, null: false
      t.string :trip_type, default: "single", null: false
      t.json :metadata, default: {}
      t.datetime :completed_at
      t.string :created_by, default: "producer", null: false

      t.timestamps
    end

    add_index :quotes, :public_token, unique: true
  end
end
