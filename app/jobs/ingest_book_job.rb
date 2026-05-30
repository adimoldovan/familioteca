class IngestBookJob < ApplicationJob
  queue_as :default

  limits_concurrency to: 1, key: "ingest"

  def perform(storage: BookStorage.default)
    modified_at = storage.list.to_h { |entry| [ entry.key, entry.last_modified ] }
    remote = modified_at.keys.to_set
    known  = Book.pluck(:object_key).to_set

    (remote - known).each do |key|
      ProcessBookFileJob.perform_later(key)
    end

    disappeared = known - remote
    Book.where(object_key: disappeared.to_a, missing_since: nil).update_all(missing_since: Time.current) if disappeared.any?

    returning = remote & known
    Book.where(object_key: returning.to_a).where.not(missing_since: nil).update_all(missing_since: nil)

    record_file_modified_times(modified_at, returning)
  end

  private

  # Store each present book's storage last-modified time so the catalog can
  # flag files that changed after we last ingested them (Book.needs_rescan).
  # We write with update_all to avoid bumping updated_at — otherwise recording
  # the file time would itself make the book look freshly updated and the
  # rescan flag would never settle. Only writes rows whose value actually
  # changed to keep scans cheap.
  def record_file_modified_times(modified_at, present_keys)
    Book.where(object_key: present_keys.to_a).find_each do |book|
      remote_time = modified_at[book.object_key]
      next if remote_time.nil? || book.file_modified_at&.to_i == remote_time.to_i

      Book.where(id: book.id).update_all(file_modified_at: remote_time)
    end
  end
end
