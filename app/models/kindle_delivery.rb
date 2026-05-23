class KindleDelivery < ApplicationRecord
  belongs_to :member
  belongs_to :book

  enum :status, { pending: 0, sent: 1, failed: 2 }, default: :pending

  def self.latest_for(member, book)
    where(member: member, book: book).order(created_at: :desc).first
  end

  def mark_sent!
    update!(status: :sent, sent_at: Time.current, error: nil)
  end

  def mark_failed!(message)
    update!(status: :failed, error: message.to_s.truncate(1_000))
  end
end
