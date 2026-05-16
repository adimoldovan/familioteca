module Admin
  class MembersController < ApplicationController
    before_action :require_admin

    def index
      head :ok
    end
  end
end
