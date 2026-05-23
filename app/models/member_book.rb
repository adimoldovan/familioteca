class MemberBook < ApplicationRecord
  belongs_to :member
  belongs_to :book

  enum :rating, { nu_mi_a_placut: 0, asa_si_asa: 1, mi_a_placut: 2 }

  validates :member_id, uniqueness: { scope: :book_id }

  def read?
    read_at.present?
  end
end
