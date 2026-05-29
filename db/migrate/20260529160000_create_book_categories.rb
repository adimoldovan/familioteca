class CreateBookCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :book_categories do |t|
      t.references :book, null: false, foreign_key: true
      t.string :category, null: false

      t.timestamps
    end

    add_index :book_categories, [ :book_id, :category ], unique: true
  end
end
