class CreateMemberBooks < ActiveRecord::Migration[8.1]
  def change
    create_table :member_books do |t|
      t.references :member, null: false, foreign_key: true
      t.references :book, null: false, foreign_key: true
      t.datetime :read_at
      t.integer :rating

      t.timestamps
    end

    add_index :member_books, [ :member_id, :book_id ], unique: true
  end
end
