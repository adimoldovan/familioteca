class RecomputeSearchableWithoutDescription < ActiveRecord::Migration[8.1]
  def up
    Book.find_each(&:save!)
  end

  def down
    Book.find_each(&:save!)
  end
end
