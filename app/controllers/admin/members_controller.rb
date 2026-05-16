module Admin
  class MembersController < BaseController
    def index
      @members = Member.order(:name)
    end
  end
end
