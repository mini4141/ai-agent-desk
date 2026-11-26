# Dashboards and experiments are for admins/owners (headless policy: authorize :metric, :index?).
class MetricPolicy < ApplicationPolicy
  def index? = admin?
  def rollup? = admin?
end
