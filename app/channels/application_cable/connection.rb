module ApplicationCable
  # Customers (widget) connect with a conversation-scoped token, operators with a user token.
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :current_conversation

    def connect
      claims = AuthToken.decode(request.params[:token]) or reject_unauthorized_connection
      ActsAsTenant.without_tenant do
        case claims["kind"]
        when "widget"
          conversation = Conversation.find_by(id: claims["conv"]) or reject_unauthorized_connection
          origin = request.origin
          reject_unauthorized_connection unless origin.blank? || conversation.company.origin_allowed?(origin)
          self.current_conversation = conversation
        when "user"
          self.current_user = User.find_by(id: claims["sub"]) or reject_unauthorized_connection
        else
          reject_unauthorized_connection
        end
      end
    end
  end
end
