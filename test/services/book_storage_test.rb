require "test_helper"

class BookStorageTest < ActiveSupport::TestCase
  setup do
    @storage = BookStorage.new(bucket: "test-bucket")
    @client  = @storage.send(:client)
  end

  test "#list returns all object keys, paginating through continuation tokens" do
    @client.stub_responses(
      :list_objects_v2,
      [
        {
          contents: [ { key: "a.epub" }, { key: "b.epub" } ],
          is_truncated: true,
          next_continuation_token: "cursor1"
        },
        {
          contents: [ { key: "c.epub" } ],
          is_truncated: false
        }
      ]
    )

    assert_equal %w[a.epub b.epub c.epub], @storage.list
  end

  test "#download writes the object body to a temp file and returns the path" do
    @client.stub_responses(:get_object, body: "epub bytes")

    path = @storage.download("a.epub")
    assert File.exist?(path)
    assert_equal "epub bytes", File.binread(path)
    File.delete(path)
  end

  test "#presigned_url returns a string URL containing the key" do
    url = @storage.presigned_url("a.epub", expires_in: 60)
    assert_kind_of String, url
    assert_includes url, "a.epub"
  end
end
