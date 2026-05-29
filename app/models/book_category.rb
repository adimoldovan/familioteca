class BookCategory < ApplicationRecord
  belongs_to :book

  validates :category, presence: true,
                       inclusion: { in: Book::CATEGORIES },
                       uniqueness: { scope: :book_id }
end
