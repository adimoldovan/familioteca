class AddKindleSenderApprovedToMembers < ActiveRecord::Migration[8.1]
  def change
    add_column :members, :kindle_sender_approved, :boolean, default: false, null: false
  end
end
