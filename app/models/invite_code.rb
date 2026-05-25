class InviteCode < ApplicationRecord
  CODE_LENGTH = 8
  AlreadyUsedError = Class.new(StandardError)

  belongs_to :used_by_member, class_name: "Member", optional: true

  validates :code, presence: true, uniqueness: true

  before_validation :generate_code, on: :create

  scope :available, -> { where(used_at: nil) }
  scope :used, -> { where.not(used_at: nil) }

  def available?
    used_at.nil?
  end

  def mark_used!(member)
    updated = self.class.where(id: id, used_at: nil)
                        .update_all(used_at: Time.current, used_by_member_id: member.id)
    raise AlreadyUsedError if updated == 0

    reload
  end

  private

  def generate_code
    self.code ||= SecureRandom.alphanumeric(CODE_LENGTH)
  end
end
