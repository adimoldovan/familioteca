class Member < ApplicationRecord
  EMAIL_FORMAT = URI::MailTo::EMAIL_REGEXP
  DEFAULT_READING_SPEED_WPM = 200
  READING_SPEED_RANGE = 50..2000

  has_secure_password
  generates_token_for :password_reset, expires_in: 24.hours do
    password_salt&.last(10)
  end

  has_many :sessions, dependent: :destroy
  has_many :member_books, dependent: :destroy
  has_many :kindle_deliveries, dependent: :destroy
  has_many :used_invite_codes, class_name: "InviteCode", foreign_key: :used_by_member_id, dependent: :nullify, inverse_of: :used_by_member

  normalizes :email, with: ->(e) { e.strip.downcase }
  normalizes :kindle_email, with: ->(e) { e.blank? ? nil : e.strip.downcase }

  validates :email,
    presence: true,
    uniqueness: true,
    format: { with: EMAIL_FORMAT }

  validates :name, presence: true

  validates :password, length: { minimum: 8 }, allow_nil: true

  validates :kindle_email,
    format: { with: EMAIL_FORMAT },
    allow_nil: true

  validates :reading_speed_wpm,
    numericality: { only_integer: true, in: READING_SPEED_RANGE }

  before_save :clear_sender_approved_without_email

  private

  def clear_sender_approved_without_email
    self.kindle_sender_approved = false if kindle_email.blank?
  end
end
