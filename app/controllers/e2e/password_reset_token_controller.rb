module E2e
  class PasswordResetTokenController < BaseController
    def create
      member = Member.find_by!(email: params[:email])
      token = member.generate_token_for(:password_reset)
      render json: { token: token, email: member.email }
    end
  end
end
