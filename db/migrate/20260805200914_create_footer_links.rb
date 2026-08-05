class CreateFooterLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :footer_links do |t|
      t.string  :label, null: false
      t.string  :url, null: false
      t.integer :position, null: false, default: 0
      t.boolean :published, null: false, default: true

      t.timestamps
    end

    add_index :footer_links, [ :published, :position ]
  end
end
