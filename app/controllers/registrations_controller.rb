class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]

  before_action :redirect_if_signed_in, only: %i[new create]
  before_action :load_invite_code, only: %i[new create]

  def new
    @member = Member.new
  end

  def create
    @member = Member.new(registration_params)

    ActiveRecord::Base.transaction do
      @member.save!
      @invite_code.mark_used!(@member)
    end

    sign_in(@member)
    redirect_to root_path
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  rescue InviteCode::AlreadyUsedError
    redirect_to sign_in_path, alert: t("registrations.invalid_code")
  end

  private

  def redirect_if_signed_in
    redirect_to root_path if signed_in?
  end

  def load_invite_code
    @invite_code = InviteCode.available.find_by(code: params[:code])
    unless @invite_code
      redirect_to sign_in_path, alert: t("registrations.invalid_code")
    end
  end

  def registration_params
    params.require(:member).permit(:name, :email, :password, :password_confirmation)
  end
end
