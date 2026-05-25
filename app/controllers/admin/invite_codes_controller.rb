module Admin
  class InviteCodesController < BaseController
    MAX_CODE_RETRIES = 3
    CodeCollisionError = Class.new(StandardError)

    def index
      @invite_codes = InviteCode.includes(:used_by_member).order(created_at: :desc)
    end

    def create
      invite_code = create_invite_code
      registration_url = register_url(invite_code.code)
      redirect_to admin_invite_codes_path, notice: t(".success", url: registration_url)
    rescue CodeCollisionError
      redirect_to admin_invite_codes_path, alert: t(".collision")
    end

    private

    def create_invite_code
      MAX_CODE_RETRIES.times do
        return InviteCode.create!
      rescue ActiveRecord::RecordNotUnique
        next
      rescue ActiveRecord::RecordInvalid => e
        raise unless e.record.errors.of_kind?(:code, :taken)
        next
      end
      raise CodeCollisionError
    end
  end
end
