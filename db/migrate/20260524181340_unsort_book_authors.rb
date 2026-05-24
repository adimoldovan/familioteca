class UnsortBookAuthors < ActiveRecord::Migration[8.1]
  # Regex intentionally inlined — do not refactor to call EpubParser.
  # This migration is frozen history.
  SORT_NAME = /\A\s*([^,]+?)\s*,\s*([^,]+?)\s*\z/
  SUFFIXES  = /\A(Jr|Sr|[IVX]+|Inc|LLC|Ltd|Co)\.?\z/i

  def up
    connection.execute("SELECT id, author FROM books WHERE author LIKE '%,%'").each do |row|
      match = row["author"].match(SORT_NAME)
      next unless match && !match[2].match?(SUFFIXES)

      new_author = "#{match[2]} #{match[1]}"
      connection.execute(
        ActiveRecord::Base.sanitize_sql([ "UPDATE books SET author = ? WHERE id = ?", new_author, row["id"] ])
      )
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
