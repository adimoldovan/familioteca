module E2e
  class SeedUserController < BaseController
    def create
      password = params[:password].presence || "password123"
      member = Member.find_or_initialize_by(email: params[:email].to_s.downcase)
      member.password = password
      member.name = params[:name].presence || member.name.presence || "E2E Member"
      # Only touch admin when the caller explicitly passed it, so a re-seed
      # without the param doesn't silently demote a previously seeded admin.
      member.admin = ActiveModel::Type::Boolean.new.cast(params[:admin]) || false if params.key?(:admin)
      if params.key?(:kindle_email)
        member.kindle_email = params[:kindle_email].presence
        member.kindle_sender_approved = member.kindle_email.present?
      end
      member.save!
      sign_in(member)
      render json: { id: member.id, email: member.email, password: password, admin: member.admin?, kindle_email: member.kindle_email, kindle_sender_approved: member.kindle_sender_approved? }
    end
  end
end
