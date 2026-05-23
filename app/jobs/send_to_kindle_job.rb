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
    broadcast_status(delivery)
  rescue StandardError => e
    mark_delivery_failed(e) unless TRANSIENT_ERRORS.any? { |k| e.is_a?(k) }
    raise
  ensure
    File.delete(@path) if @path && File.exist?(@path)
  end

  def mark_delivery_failed(error)
    delivery = KindleDelivery.find_by(id: @delivery_id)
    return unless delivery
    delivery.mark_failed!(error.message)
    broadcast_status(delivery)
  end

  private

  # Scoped per (book, member) so other members viewing the same book don't
  # receive a render of THIS member's button state into their session.
  def broadcast_status(delivery)
    Turbo::StreamsChannel.broadcast_replace_to(
      [ delivery.book, delivery.member, :kindle_status ],
      target: "book-kindle",
      partial: "books/kindle_button",
      locals: { book: delivery.book, latest_delivery: delivery, member: delivery.member }
    )
  rescue StandardError => e
    # A cable failure must not flip the delivery row back to failed; the user
    # will see the final state on the next page load instead.
    Rails.logger.warn("Kindle broadcast failed for delivery #{delivery.id}: #{e.class}: #{e.message}")
  end
end
