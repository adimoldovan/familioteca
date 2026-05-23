class AccountsController < ApplicationController
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
    params.require(:member).permit(:name, :kindle_email)
  end
end
