module E2e
  class PerformJobsController < BaseController
    include ActiveJob::TestHelper

    def create
      drained = perform_enqueued_jobs
      render json: { drained: drained.size }
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
