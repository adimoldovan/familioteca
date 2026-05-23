require "net/smtp"

class SendToKindleJob < ApplicationJob
  queue_as :default

  # Splatted into retry_on below and consulted in the rescue. If you add a new
  # retryable error, add it here — otherwise the rescue will prematurely mark
  # the row failed before retry_on gets a chance to retry.
  TRANSIENT_ERRORS = [
    Seahorse::Client::NetworkingError,
    Aws::S3::Errors::RequestTimeout,
    Aws::S3::Errors::ServiceUnavailable,
    Aws::S3::Errors::SlowDown,
    Aws::S3::Errors::InternalError,
    Net::SMTPServerBusy,
    Net::OpenTimeout,
    Net::ReadTimeout
  ].freeze

  retry_on(*TRANSIENT_ERRORS, wait: :polynomially_longer, attempts: 3) do |job, error|
    job.mark_delivery_failed(error)
  end

  def perform(delivery_id, storage: BookStorage.default)
    @delivery_id = delivery_id
    delivery = KindleDelivery.find(delivery_id)
    @path = storage.download(delivery.book.object_key)
    KindleMailer.with(delivery: delivery, file_path: @path).deliver_book.deliver_now
    delivery.mark_sent!
  rescue StandardError => e
    mark_delivery_failed(e) unless TRANSIENT_ERRORS.any? { |k| e.is_a?(k) }
    raise
  ensure
    File.delete(@path) if @path && File.exist?(@path)
  end

  def mark_delivery_failed(error)
    KindleDelivery.find_by(id: @delivery_id)&.mark_failed!(error.message)
  end
end
