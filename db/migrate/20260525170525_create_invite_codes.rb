class CreateInviteCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :invite_codes do |t|
      t.string :code, null: false
      t.references :used_by_member, foreign_key: { to_table: :members }
      t.datetime :used_at

      t.timestamps
    end

    add_index :invite_codes, :code, unique: true
  end
end
