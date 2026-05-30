require "test_helper"

class BookStorageTest < ActiveSupport::TestCase
  setup do
    @storage = BookStorage.new(bucket: "test-bucket")
    @client  = @storage.send(:client)
  end

  test "#list returns each object's key and last-modified time, paginating through continuation tokens" do
    modified = Time.utc(2026, 1, 2, 3, 4, 5)
    @client.stub_responses(
      :list_objects_v2,
      [
        {
          contents: [ { key: "a.epub", last_modified: modified }, { key: "b.epub", last_modified: modified } ],
          is_truncated: true,
          next_continuation_token: "cursor1"
        },
        {
          contents: [ { key: "c.epub", last_modified: modified } ],
          is_truncated: false
        }
      ]
    )

    entries = @storage.list
    assert_equal %w[a.epub b.epub c.epub], entries.map(&:key)
    assert_equal [ modified, modified, modified ], entries.map(&:last_modified)
  end

  test "#download writes the object body to a temp file and returns the path" do
    @client.stub_responses(:get_object, body: "epub bytes")

    path = @storage.download("a.epub")
    assert File.exist?(path)
    assert_equal "epub bytes", File.binread(path)
    File.delete(path)
  end

  test "#download deletes the tempfile and re-raises if get_object raises mid-stream" do
    tempfile = Tempfile.new([ "familioteca-leak-test-", ".epub" ])
    tempfile.binmode
    path = tempfile.path

    @client.stub_responses(:get_object, RuntimeError.new("network drop"))

    error = with_tempfile_new_returning(tempfile) do
      assert_raises(RuntimeError) { @storage.download("a.epub") }
    end

    assert_equal "network drop", error.message,
      "rescue must re-raise the original exception unchanged"
    refute File.exist?(path), "tempfile was not deleted after mid-stream error"
  end

  test "#presigned_url returns a string URL containing the key" do
    url = @storage.presigned_url("a.epub", expires_in: 60)
    assert_kind_of String, url
    assert_includes url, "a.epub"
  end

  test ".bucket_name uses FAMILIOTECA_BUCKET_NAME when set" do
    with_env("FAMILIOTECA_BUCKET_NAME" => "explicit-bucket") do
      assert_equal "explicit-bucket", BookStorage.bucket_name
    end
  end

  test ".bucket_name falls back to familioteca-<env> outside production when env var is unset" do
    with_env("FAMILIOTECA_BUCKET_NAME" => nil) do
      assert_equal "familioteca-test", BookStorage.bucket_name
    end
  end

  test ".bucket_name raises in production when env var is unset" do
    with_env("FAMILIOTECA_BUCKET_NAME" => nil) do
      with_rails_env("production") do
        error = assert_raises(RuntimeError) { BookStorage.bucket_name }
        assert_match(/FAMILIOTECA_BUCKET_NAME is required/, error.message)
      end
    end
  end

  test ".bucket_name raises in production when env var is empty string" do
    with_env("FAMILIOTECA_BUCKET_NAME" => "") do
      with_rails_env("production") do
        error = assert_raises(RuntimeError) { BookStorage.bucket_name }
        assert_match(/FAMILIOTECA_BUCKET_NAME is required/, error.message)
      end
    end
  end

  private

  # Safe only under process-based parallelism (the default). Tempfile's
  # singleton class is process-global; do not use with :threads parallelism.
  def with_tempfile_new_returning(tempfile)
    original = Tempfile.singleton_class.instance_method(:new)
    Tempfile.singleton_class.define_method(:new) { |*_, **_| tempfile }
    yield
  ensure
    Tempfile.singleton_class.define_method(:new, original)
  end

  def with_env(values)
    original = values.each_key.to_h { |k| [ k, ENV.key?(k) ? ENV[k] : :__unset__ ] }
    values.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    yield
  ensure
    original.each do |k, v|
      v == :__unset__ ? ENV.delete(k) : ENV[k] = v
    end
  end

  # Safe only under process-based parallelism (the default). Rails.env is
  # process-global; do not use with :threads parallelism.
  def with_rails_env(env)
    original = Rails.env
    Rails.env = env
    yield
  ensure
    Rails.env = original
  end
end
