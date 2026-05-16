class Book < ApplicationRecord
  FORMATS = %w[epub mobi pdf].freeze

  has_one_attached :cover

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

  def missing?
    missing_since.present?
  end

  private

  def populate_search_columns
    self.sort_title = DiacriticFolding.fold(title.to_s)
    self.searchable = DiacriticFolding.fold(
      [ title, author, description ].compact_blank.join(" ")
    )
  end
end
