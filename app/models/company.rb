class Company < ApplicationRecord
  encrypts :webhook_secret

  has_many :users, dependent: :destroy
  has_many :knowledge_sources, dependent: :destroy
  has_many :tools, dependent: :destroy
  has_many :conversations, dependent: :destroy

  before_validation { self.public_key ||= "pk_#{SecureRandom.hex(12)}" }
  validates :name, :slug, :locale, presence: true
  validates :locale, inclusion: { in: %w[ja en] }

  def japanese? = locale == "ja"

  # Widget origin allow-list; an empty list or "*" means any origin (local development).
  def origin_allowed?(origin)
    allowed_origins.empty? || allowed_origins.include?("*") || allowed_origins.include?(origin.to_s)
  end

  def setting(key, default = nil) = settings.fetch(key.to_s, default)

  def as_api
    { id:, name:, slug:, locale:, public_key:, allowed_origins:, settings: }
  end
end
