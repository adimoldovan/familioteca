class IngestBookJob < ApplicationJob
  queue_as :default

  limits_concurrency to: 1, key: "ingest"

  def perform(storage: BookStorage.default)
    remote = storage.list.to_set
    known  = Book.pluck(:object_key).to_set

    (remote - known).each do |key|
      ProcessBookFileJob.perform_later(key)
    end

    disappeared = known - remote
    Book.where(object_key: disappeared.to_a, missing_since: nil).update_all(missing_since: Time.current) if disappeared.any?

    returning = remote & known
    Book.where(object_key: returning.to_a).where.not(missing_since: nil).update_all(missing_since: nil)
  end
end
