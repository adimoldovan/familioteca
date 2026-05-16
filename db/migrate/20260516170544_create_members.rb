class CreateMembers < ActiveRecord::Migration[8.1]
  def change
    create_table :members do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :name, null: false
      t.string :kindle_email
      t.boolean :admin, null: false, default: false

      t.timestamps
    end
    add_index :members, :email, unique: true
  end
end
