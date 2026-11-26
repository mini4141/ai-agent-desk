# Operators work conversations; every role may.
class ConversationPolicy < ApplicationPolicy
  def assign? = user.present?
  def handback? = user.present?
  def resolve? = user.present?
end
