class User < ApplicationRecord
  acts_as_tenant :company
  has_secure_password
  has_many :sessions, dependent: :destroy

  enum :role, { owner: "owner", admin: "admin", operator: "operator" }, validate: true
  normalizes :email, with: ->(e) { e.strip.downcase }
  validates :email, presence: true, uniqueness: true

  def admin_or_owner? = owner? || admin?

  def as_api = { id:, email:, name:, role: }
end
