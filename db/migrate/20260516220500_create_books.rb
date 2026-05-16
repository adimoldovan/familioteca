class CreateBooks < ActiveRecord::Migration[8.1]
  def change
    create_table :books do |t|
      t.string :title, null: false
      t.string :author
      t.string :language
      t.string :publisher
      t.integer :published_year
      t.string :isbn
      t.text :description
      t.string :format, null: false
      t.string :object_key, null: false
      t.integer :file_size
      t.datetime :ingested_at, null: false
      t.datetime :missing_since
      t.text :parse_error
      t.string :sort_title, null: false
      t.text :searchable, null: false

      t.timestamps
    end

    add_index :books, :object_key, unique: true
    add_index :books, :sort_title
    add_index :books, :missing_since
  end
end
