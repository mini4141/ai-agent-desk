module Api
  module V1
    class SessionsController < ApplicationController
      def create
        user = ActsAsTenant.without_tenant { User.find_by(email: params[:email].to_s.strip.downcase) }
        return render(json: { error: "invalid_credentials" }, status: :unauthorized) unless user&.authenticate(params[:password].to_s)

        session = user.sessions.create!(ip_address: request.remote_ip, user_agent: request.user_agent)
        cookies.signed[:session_id] = { value: session.id, httponly: true, same_site: :lax, expires: 12.hours.from_now }
        render json: {
          token: AuthToken.encode({ kind: "user", sub: user.id, cid: user.company_id }),
          user: user.as_api, company: user.company.as_api
        }
      end

      def destroy
        Session.where(id: cookies.signed[:session_id]).delete_all
        cookies.delete(:session_id)
        head :no_content
      end
    end
  end
end
