module Authentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_member, :signed_in?
    before_action :require_login
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_login, **options
    end
  end

  private

  def current_member
    return @current_member if defined?(@current_member)
    Current.member ||= load_member_from_session
    @current_member = Current.member
  end

  def signed_in?
    current_member.present?
  end

  def require_login
    return if signed_in?
    redirect_to sign_in_path
  end

  def require_admin
    return if current_member&.admin?
    raise ActionController::RoutingError.new("Not Found")
  end

  def sign_in(member)
    session_record = member.sessions.create!(
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    )
    cookies.permanent[:session_token] = { value: session_record.token, httponly: true }
    Current.member = member
    @current_member = member
  end

  def sign_out
    Session.find_by(token: cookies[:session_token])&.destroy
    cookies.delete(:session_token)
    Current.member = nil
    @current_member = nil
  end

  def load_member_from_session
    token = cookies[:session_token]
    return nil unless token
    Session.find_by(token: token)&.member
  end
end
