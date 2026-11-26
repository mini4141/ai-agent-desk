module Widget
  module V1
    # End-of-chat thumbs. A thumbs-up/down on an AI-only conversation also marks it resolved (deflected).
    class CsatController < ApplicationController
      def create
        claims = AuthToken.decode(request.authorization.to_s[/\ABearer (.+)\z/, 1])
        return head(:unauthorized) unless claims && claims["kind"] == "widget" && claims["conv"].to_s == params[:id].to_s

        conversation = ActsAsTenant.without_tenant { Conversation.find(params[:id]) }
        ActsAsTenant.with_tenant(conversation.company) do
          conversation.update!(csat: params[:score].to_s == "up" ? 5 : 1)
          conversation.resolve! if conversation.ai?
        end
        render json: { ok: true }
      end
    end
  end
end
