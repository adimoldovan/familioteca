class NormalizeBookLanguages < ActiveRecord::Migration[8.1]
  def up
    Book.where.not(language: [ nil, "" ]).find_each do |book|
      normalized = LanguageNormalizer.normalize(book.language)
      book.update_column(:language, normalized) if normalized != book.language
    end
  end

  def down
    # Language values before normalization are not recoverable.
  end
end
