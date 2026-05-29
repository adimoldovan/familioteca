class AddWordCountToBooks < ActiveRecord::Migration[8.1]
  def change
    add_column :books, :word_count, :integer
  end
end
