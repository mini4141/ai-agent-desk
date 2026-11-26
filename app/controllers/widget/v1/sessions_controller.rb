module Widget
  module V1
    # Public-key authenticated: creates a conversation for a visitor and returns the cable token.
    class SessionsController < ApplicationController
      CHANNELS = %w[web_chat voice_web avatar phone_sim].freeze

      def create
        company = ActsAsTenant.without_tenant { Company.find_by(public_key: params[:public_key]) }
        return render(json: { error: "invalid_key" }, status: :unauthorized) unless company
        return render(json: { error: "origin_not_allowed" }, status: :forbidden) unless request.origin.blank? || company.origin_allowed?(request.origin)

        ActsAsTenant.with_tenant(company) do
          visitor = params[:visitor_id].presence || SecureRandom.uuid
          variant = Flipper.enabled?(:greeting_v2, VisitorActor.new(visitor)) ? "greeting_v2" : "control"
          interview = params[:mode] == "interview"
          conversation = Conversation.create!(
            channel: CHANNELS.include?(params[:channel]) ? params[:channel] : "web_chat",
            variant:, visitor_id: visitor, language: company.locale, mode: interview ? "interview" : "chat", started_at: Time.current
          )
          render json: payload(company, conversation, variant, interview), status: :created
        end
      end

      private

      def payload(company, conversation, variant, interview)
        {
          conversation_id: conversation.id, visitor_id: conversation.visitor_id, variant:, channel: conversation.channel,
          token: AuthToken.encode({ kind: "widget", conv: conversation.id }, expires_in: 1.day),
          company: { name: company.name, locale: company.locale, slug: company.slug },
          greeting: company.setting(variant == "greeting_v2" ? "greeting_v2" : "greeting"),
          suggestions: variant == "greeting_v2" ? company.setting("suggested_questions", []) : [],
          opening: (IntakeFlow.new(conversation, company.locale).opening if interview)
        }
      end
    end
  end
end
