class Member < ApplicationRecord
  EMAIL_FORMAT = URI::MailTo::EMAIL_REGEXP

  has_secure_password
  generates_token_for :password_reset, expires_in: 24.hours do
    password_salt&.last(10)
  end

  has_many :sessions, dependent: :destroy
  has_many :member_books, dependent: :destroy
  has_many :kindle_deliveries, dependent: :destroy

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
end
