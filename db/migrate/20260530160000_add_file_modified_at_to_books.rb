class AddFileModifiedAtToBooks < ActiveRecord::Migration[8.1]
  def change
    add_column :books, :file_modified_at, :datetime
  end
end
