module Api
  module V1
    class ConversationsController < BaseController
      before_action :load_conversation, except: :index

      def index
        scope = policy_scope(Conversation)
        scope = params[:status] == "resolved" ? scope.resolved.order(last_message_at: :desc) : scope.inbox
        scope = scope.where(channel: params[:channel]) if params[:channel].present?
        render json: { conversations: scope.limit(100).map(&:as_api) }
      end

      def show
        authorize @conversation
        render json: @conversation.as_api.merge(messages: @conversation.messages.order(:created_at).map(&:as_api))
      end

      def assign
        authorize @conversation
        @conversation.assign!(current_user)
        render json: @conversation.as_api
      end

      def handback
        authorize @conversation
        @conversation.handback!
        render json: @conversation.as_api
      end

      def resolve
        authorize @conversation
        @conversation.resolve!
        render json: @conversation.as_api
      end

      # Operator reply (typically the AI draft, edited). Sending takes over a waiting conversation.
      def create_message
        authorize @conversation, :resolve?
        @conversation.assign!(current_user) unless @conversation.human?
        message = @conversation.messages.create!(role: "operator", content: params.require(:content), metadata: { "operator" => current_user.name })
        @conversation.update_columns(draft_reply: nil)
        render json: message.as_api, status: :created
      end

      def tags
        authorize @conversation, :resolve?
        @conversation.update!(tags: Array(params[:tags]).map(&:to_s).first(10))
        render json: @conversation.as_api
      end

      private

      def load_conversation = @conversation = Conversation.find(params[:id])
    end
  end
end
