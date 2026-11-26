# Pundit policies decide by role; tenant isolation itself is enforced by acts_as_tenant scoping.
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index? = user.present?
  def show? = user.present?
  def create? = admin?
  def update? = admin?
  def destroy? = admin?

  private

  def admin? = user&.admin_or_owner?

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve = scope.all

    private

    attr_reader :user, :scope
  end
end
