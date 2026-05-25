module Admin
  class MembersController < BaseController
    def index
      @members = Member.order(:name)
    end

    def destroy
      @member = Member.find(params[:id])

      if @member == current_member
        redirect_to admin_members_path, alert: t(".self_delete")
        return
      end

      if @member.admin? && Member.where(admin: true).count <= 1
        redirect_to admin_members_path, alert: t(".last_admin")
        return
      end

      @member.destroy!
      redirect_to admin_members_path, notice: t(".success")
    end

    def reset_link
      @member = Member.find(params[:id])
      token = @member.generate_token_for(:password_reset)
      @reset_url = edit_password_reset_url(token: token)
    end
  end
end
