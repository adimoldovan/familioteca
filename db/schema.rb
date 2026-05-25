# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_25_170525) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "books", force: :cascade do |t|
    t.string "author"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "file_size"
    t.string "format", null: false
    t.string "goodreads_url"
    t.datetime "ingested_at", null: false
    t.string "isbn"
    t.string "language"
    t.datetime "missing_since"
    t.string "object_key", null: false
    t.text "parse_error"
    t.integer "published_year"
    t.string "publisher"
    t.text "searchable", null: false
    t.string "sort_title", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["missing_since"], name: "index_books_on_missing_since"
    t.index ["object_key"], name: "index_books_on_object_key", unique: true
    t.index ["sort_title"], name: "index_books_on_sort_title"
  end

  create_table "invite_codes", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.integer "used_by_member_id"
    t.index ["code"], name: "index_invite_codes_on_code", unique: true
    t.index ["used_by_member_id"], name: "index_invite_codes_on_used_by_member_id"
  end

  create_table "kindle_deliveries", force: :cascade do |t|
    t.integer "book_id", null: false
    t.datetime "created_at", null: false
    t.text "error"
    t.integer "member_id", null: false
    t.datetime "sent_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_kindle_deliveries_on_book_id"
    t.index ["member_id", "book_id", "created_at"], name: "index_kindle_deliveries_on_member_book_created"
    t.index ["member_id"], name: "index_kindle_deliveries_on_member_id"
  end

  create_table "member_books", force: :cascade do |t|
    t.integer "book_id", null: false
    t.datetime "created_at", null: false
    t.integer "member_id", null: false
    t.integer "rating"
    t.datetime "read_at"
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_member_books_on_book_id"
    t.index ["member_id", "book_id"], name: "index_member_books_on_member_id_and_book_id", unique: true
    t.index ["member_id"], name: "index_member_books_on_member_id"
  end

  create_table "members", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "kindle_email"
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_members_on_email", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.integer "member_id", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["member_id"], name: "index_sessions_on_member_id"
    t.index ["token"], name: "index_sessions_on_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "invite_codes", "members", column: "used_by_member_id"
  add_foreign_key "kindle_deliveries", "books"
  add_foreign_key "kindle_deliveries", "members"
  add_foreign_key "member_books", "books"
  add_foreign_key "member_books", "members"
  add_foreign_key "sessions", "members"
end
