class CreateTravelers < ActiveRecord::Migration[8.0]
  def change
    create_table :travelers do |t|
      t.references :company, null: false, foreign_key: true
      t.references :producer, null: false, foreign_key: { to_table: :users }
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.string :phone
      t.string :document
      t.date :birth_date

      t.timestamps
    end
  end
end
