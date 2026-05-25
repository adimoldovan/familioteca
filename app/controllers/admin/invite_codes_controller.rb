module Admin
  class InviteCodesController < BaseController
    def index
      @invite_codes = InviteCode.includes(:used_by_member).order(created_at: :desc)
    end

    def create
      invite_code = InviteCode.create!
      registration_url = register_url(invite_code.code)
      redirect_to admin_invite_codes_path, notice: t(".success", url: registration_url)
    end
  end
end
