module E2e
  class PerformJobsController < BaseController
    include ActiveJob::TestHelper

    ALLOWED_JOBS = {
      "SendToKindleJob" => SendToKindleJob
    }.freeze

    def create
      opts = {}
      if params[:only].present?
        klass = ALLOWED_JOBS[params[:only]]
        return render json: { error: "Unknown job class: #{params[:only]}" }, status: :unprocessable_entity unless klass
        opts[:only] = klass
      end
      drained = perform_enqueued_jobs(**opts)
      render json: { drained: drained }
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
