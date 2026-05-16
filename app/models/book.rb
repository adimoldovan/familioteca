class Book < ApplicationRecord
  FORMATS = %w[epub mobi pdf].freeze

  has_one_attached :cover

  validates :title, presence: true
  validates :object_key, presence: true, uniqueness: true
  validates :format, presence: true, inclusion: { in: FORMATS }
  validates :ingested_at, presence: true

  before_validation :populate_search_columns

  private

  def populate_search_columns
    self.sort_title = DiacriticFolding.fold(title.to_s)
    self.searchable = DiacriticFolding.fold(
      [ title, author, description ].compact_blank.join(" ")
    )
  end
end
