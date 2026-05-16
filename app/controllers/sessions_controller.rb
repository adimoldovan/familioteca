class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]

  def new
  end

  def create
    member = Member.find_by(email: params[:email].to_s.strip.downcase)
    if member&.authenticate(params[:password])
      sign_in(member)
      redirect_to root_path
    else
      flash.now[:error] = I18n.t("sessions.new.invalid")
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    sign_out
    redirect_to sign_in_path
  end
end
