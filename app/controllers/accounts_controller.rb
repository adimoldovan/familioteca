class AccountsController < ApplicationController
  before_action :set_sender_email, only: %i[show update]

  def show
    @member = current_member
  end

  def update
    @member = current_member
    if @member.update(account_params)
      redirect_to account_path, notice: t("account.update.success")
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def account_params
    params.require(:member).permit(:name, :kindle_email, :kindle_sender_approved)
  end

  def set_sender_email
    @sender_email = ApplicationMailer.default[:from]
  end
end
