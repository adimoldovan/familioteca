class Book < ApplicationRecord
  FORMATS = %w[epub mobi pdf].freeze

  has_one_attached :cover

  validates :title, presence: true
  validates :object_key, presence: true, uniqueness: true
  validates :format, presence: true, inclusion: { in: FORMATS }
  validates :ingested_at, presence: true
end
