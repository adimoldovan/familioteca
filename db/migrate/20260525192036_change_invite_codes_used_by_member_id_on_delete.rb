class ChangeInviteCodesUsedByMemberIdOnDelete < ActiveRecord::Migration[8.1]
  def up
    remove_foreign_key :invite_codes, :members, column: :used_by_member_id
    add_foreign_key :invite_codes, :members, column: :used_by_member_id, on_delete: :nullify
  end

  def down
    remove_foreign_key :invite_codes, :members, column: :used_by_member_id
    add_foreign_key :invite_codes, :members, column: :used_by_member_id
  end
end
