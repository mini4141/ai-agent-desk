# Console/API authentication: JWT bearer token (API) or the signed session cookie (console),
# then every action runs inside the signed-in user's tenant.
module Authentication
  extend ActiveSupport::Concern

  included do
    around_action :authenticate
  end

  private

  attr_reader :current_user

  def pundit_user = current_user

  def authenticate
    @current_user = user_from_bearer || user_from_cookie
    return render(json: { error: "unauthenticated" }, status: :unauthorized) unless @current_user

    ActsAsTenant.with_tenant(@current_user.company) { yield }
  end

  def user_from_bearer
    token = request.authorization.to_s[/\ABearer (.+)\z/, 1] or return
    claims = AuthToken.decode(token)
    return unless claims && claims["kind"] == "user"

    ActsAsTenant.without_tenant { User.find_by(id: claims["sub"]) }
  end

  def user_from_cookie
    session = Session.find_by(id: cookies.signed[:session_id]) or return
    ActsAsTenant.without_tenant { User.find_by(id: session.user_id) }
  end
end
