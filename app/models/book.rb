class Book < ApplicationRecord
  FORMATS = %w[epub mobi pdf].freeze

  has_one_attached :cover do |attachable|
    attachable.variant :thumbnail, resize_to_limit: [ 360, 540 ], format: :webp, saver: { quality: 85 }
  end

  has_many :member_books, dependent: :destroy

  validates :title, presence: true
  validates :object_key, presence: true, uniqueness: true
  validates :format, presence: true, inclusion: { in: FORMATS }
  validates :ingested_at, presence: true

  before_validation :populate_search_columns

  scope :visible,        -> { where(missing_since: nil).where(parse_error: nil) }
  scope :needs_metadata, -> { where.not(parse_error: nil) }

  scope :search, ->(query) {
    folded = DiacriticFolding.fold(query.to_s.strip)
    next all if folded.blank?
    where("searchable LIKE ?", "%#{sanitize_sql_like(folded)}%")
  }

  def member_book_for(member)
    member_books.find_or_initialize_by(member: member)
  end

  def missing?
    missing_since.present?
  end

  def cover_thumbnail
    return nil unless cover.attached? && cover.variable?
    cover.variant(:thumbnail)
  end

  private

  def populate_search_columns
    self.sort_title = DiacriticFolding.fold(title.to_s)
    self.searchable = DiacriticFolding.fold(
      [ title, author, description ].compact_blank.join(" ")
    )
  end
end
