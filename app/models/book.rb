class Book < ApplicationRecord
  FORMATS = %w[epub mobi pdf].freeze
  CATEGORIES = %w[fiction non_fiction biography essays].freeze
  KINDLE_MAX_SIZE = 24.megabytes

  has_one_attached :cover do |attachable|
    attachable.variant :thumbnail, resize_to_limit: [ 360, 540 ], format: :webp, saver: { quality: 85 }
  end

  has_many :member_books, dependent: :destroy
  has_many :kindle_deliveries, dependent: :destroy
  has_many :book_categories, dependent: :destroy

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

  # The storage file changed after our last DB write, so a rescan would pull in
  # updates we'd otherwise miss. file_modified_at is recorded during the scan;
  # updated_at moves whenever we process the file or an admin edits the book, so
  # a manual edit naturally clears the flag without clobbering the edit.
  scope :needs_rescan,     -> { visible.where("books.file_modified_at > books.updated_at") }

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

  scope :without_category, -> { visible.where.missing(:book_categories) }

  scope :by_category, ->(cats) {
    cats = Array(cats).select { |c| CATEGORIES.include?(c) }
    next all if cats.empty?
    where(id: BookCategory.where(category: cats).select(:book_id))
  }

  def self.available_languages
    visible.where.not(language: [ nil, "" ]).distinct.pluck(:language).sort
  end

  def category_keys
    book_categories.map(&:category)
  end

  # Replace this book's categories with the given keys (unknown keys ignored).
  # Adds/removes only what changed so existing rows keep their timestamps.
  def sync_categories(keys)
    desired = Array(keys).map(&:to_s).select { |k| CATEGORIES.include?(k) }.uniq
    current = category_keys # snapshot before mutating, the cache can go stale
    transaction do
      book_categories.where.not(category: desired).destroy_all
      (desired - current).each { |k| book_categories.create!(category: k) }
    end
    book_categories.reset
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

  # Mirrors the needs_rescan scope (visible books only) so a book's row badge
  # never disagrees with the filter tab.
  def needs_rescan?
    return false if missing_since.present? || parse_error.present?
    return false if file_modified_at.nil? || updated_at.nil?
    file_modified_at > updated_at
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
