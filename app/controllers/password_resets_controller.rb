class PasswordResetsController < ApplicationController
  allow_unauthenticated_access

  before_action :set_member_from_token

  def edit
  end

  def update
    if @member.update(password_params)
      redirect_to sign_in_path, notice: t(".success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_member_from_token
    @member = Member.find_by_token_for(:password_reset, params[:token])
    return if @member

    redirect_to sign_in_path, alert: t("password_resets.invalid_token")
  end

  def password_params
    params.require(:member).permit(:password, :password_confirmation)
  end
end
