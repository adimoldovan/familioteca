class AddGoodreadsUrlToBooks < ActiveRecord::Migration[8.1]
  def change
    add_column :books, :goodreads_url, :string
  end
end
