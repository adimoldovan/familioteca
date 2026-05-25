module Admin
  class MembersController < BaseController
    def index
      @members = Member.order(:name)
    end

    def reset_link
      @member = Member.find(params[:id])
      token = @member.generate_token_for(:password_reset)
      @reset_url = edit_password_reset_url(token: token)
    end
  end
end
