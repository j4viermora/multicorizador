class CreateTestimonials < ActiveRecord::Migration[8.0]
  def change
    create_table :testimonials do |t|
      t.string  :author_name, null: false
      t.string  :location
      t.string  :source
      t.string  :source_url
      t.integer :rating, null: false, default: 5
      t.text    :body, null: false
      t.integer :position, null: false, default: 0
      t.boolean :published, null: false, default: true

      t.timestamps
    end

    add_index :testimonials, [ :published, :position ]
  end
end
