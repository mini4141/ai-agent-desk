# Workflow tools are admin settings: operators can't list or edit them.
class ToolPolicy < ApplicationPolicy
  def index? = admin?
  def test? = admin?
end
