class Book < ApplicationRecord
  FORMATS = %w[epub mobi pdf].freeze
  KINDLE_MAX_SIZE = 24.megabytes

  has_one_attached :cover do |attachable|
    attachable.variant :thumbnail, resize_to_limit: [ 360, 540 ], format: :webp, saver: { quality: 85 }
  end

  has_many :member_books, dependent: :destroy
  has_many :kindle_deliveries, dependent: :destroy

  validates :title, presence: true
  validates :object_key, presence: true, uniqueness: true
  validates :format, presence: true, inclusion: { in: FORMATS }
  validates :ingested_at, presence: true
  validates :goodreads_url, format: { with: %r{\Ahttps://www\.goodreads\.com/book/show/\S+\z}, message: :invalid },
                            allow_blank: true

  before_validation :normalize_language
  before_validation :populate_search_columns

  scope :visible,          -> { where(missing_since: nil).where(parse_error: nil) }
  scope :needs_metadata,   -> { where.not(parse_error: nil) }
  scope :needs_goodreads,  -> { visible.where(goodreads_url: [ nil, "" ]) }

  scope :search, ->(query) {
    folded = DiacriticFolding.fold(query.to_s.strip)
    next all if folded.blank?
    where("searchable LIKE ?", "%#{sanitize_sql_like(folded)}%")
  }

  scope :by_language, ->(langs) {
    langs = Array(langs).reject(&:blank?)
    next all if langs.empty?
    where(language: langs)
  }

  def self.available_languages
    visible.where.not(language: [ nil, "" ]).distinct.pluck(:language).sort
  end

  def member_book_for(member)
    member_books.find_or_initialize_by(member: member)
  end

  # Unknown size (nil) returns false intentionally: callers should let the send attempt fail loudly.
  def oversize_for_kindle?
    return false if file_size.nil?
    file_size > KINDLE_MAX_SIZE
  end

  def missing?
    missing_since.present?
  end

  # Estimated reading time in whole minutes at the given words-per-minute
  # speed, or nil when the book has no parsed word count (non-EPUB formats
  # and parse failures). Rounds up so short books still read as "1 min".
  def reading_minutes(wpm)
    return nil if word_count.nil? || wpm.to_i <= 0
    (word_count / wpm.to_f).ceil
  end

  def cover_thumbnail
    return nil unless cover.attached? && cover.variable?
    cover.variant(:thumbnail)
  end

  private

  def normalize_language
    self.language = LanguageNormalizer.normalize(language)
  end

  def populate_search_columns
    self.sort_title = DiacriticFolding.fold(title.to_s)
    self.searchable = DiacriticFolding.fold(
      [ title, author ].compact_blank.join(" ")
    )
  end
end
