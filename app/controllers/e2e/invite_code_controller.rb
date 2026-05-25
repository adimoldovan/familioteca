module E2e
  class InviteCodeController < BaseController
    MAX_CODE_RETRIES = 3

    def create
      invite = create_invite_code
      return head :conflict unless invite

      render json: { code: invite.code }
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
      nil
    end
  end
end
