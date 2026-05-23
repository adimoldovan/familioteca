class CreateKindleDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :kindle_deliveries do |t|
      t.references :member, null: false, foreign_key: true
      t.references :book, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.text :error
      t.datetime :sent_at

      t.timestamps
    end

    add_index :kindle_deliveries, [ :member_id, :book_id, :created_at ],
              name: "index_kindle_deliveries_on_member_book_created"
  end
end
