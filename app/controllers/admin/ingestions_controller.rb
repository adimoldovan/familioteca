module Admin
  class IngestionsController < BaseController
    def create
      IngestBookJob.perform_later

      respond_to do |format|
        format.turbo_stream
        format.html do
          redirect_back_or_to admin_members_path,
            notice: t("admin.ingestions.queued")
        end
      end
    end
  end
end
