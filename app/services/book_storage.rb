require "aws-sdk-s3"
require "tempfile"

class BookStorage
  # One stored object: its key plus the storage-side last-modified time. The
  # scan compares last_modified against each book's recorded file_modified_at
  # to flag files that changed after we last ingested them.
  Entry = Struct.new(:key, :last_modified)

  # Memoized at the class level — fine because the underlying Aws::S3::Client
  # is thread-safe and tests inject their own stub via the `storage:` kwarg
  # on jobs rather than touching `.default`. If a future test calls `.default`
  # directly, reset with `BookStorage.instance_variable_set(:@default, nil)`.
  def self.default
    @default ||= new(bucket: bucket_name)
  end

  def self.bucket_name
    name = ENV["FAMILIOTECA_BUCKET_NAME"].presence
    return name if name
    raise "FAMILIOTECA_BUCKET_NAME is required in production" if Rails.env.production?
    "familioteca-#{Rails.env}"
  end

  def initialize(bucket:, client: Aws::S3::Client.new)
    @bucket = bucket
    @client = client
  end

  def list
    entries = []
    continuation = nil
    loop do
      params = { bucket: @bucket }
      params[:continuation_token] = continuation if continuation
      response = @client.list_objects_v2(**params)
      response.contents.each { |obj| entries << Entry.new(obj.key, obj.last_modified) }
      break unless response.is_truncated
      continuation = response.next_continuation_token
    end
    entries
  end

  # Returns a path. The caller owns the file and must delete it.
  # We detach Tempfile's GC finalizer so the file survives until the caller
  # cleans up explicitly (jobs do this in an `ensure` block). If streaming
  # raises mid-download, we clean up here ourselves before re-raising —
  # otherwise the caller never gets a path and the partial file leaks.
  def download(key)
    file = Tempfile.new([ "familioteca-", File.extname(key) ])
    file.binmode
    ObjectSpace.undefine_finalizer(file)
    @client.get_object(bucket: @bucket, key: key) do |chunk|
      file.write(chunk)
    end
    file.close
    file.path
  rescue StandardError
    if file
      file.close unless file.closed?
      File.delete(file.path) if File.exist?(file.path)
    end
    raise
  end

  def presigned_url(key, expires_in:)
    signer = Aws::S3::Presigner.new(client: @client)
    signer.presigned_url(:get_object, bucket: @bucket, key: key, expires_in: expires_in)
  end

  private

  # Test seam: lets specs reach the underlying client via `send(:client)`
  # to install `stub_responses` without exposing it publicly.
  attr_reader :client
end
