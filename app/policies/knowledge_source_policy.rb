class KnowledgeSourcePolicy < ApplicationPolicy
  def reindex? = admin?
end
