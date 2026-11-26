require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_cable/engine"

Bundler.require(*Rails.groups)

module App
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])
    config.api_only = true
    config.time_zone = "Tokyo"
    config.active_job.queue_adapter = :sidekiq
    config.i18n.default_locale = :ja
    config.i18n.available_locales = %i[ja en]

    # API-only apps drop cookie middleware; the console uses a signed session cookie too.
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use Rack::Attack

    config.action_cable.mount_path = nil # mounted explicitly in routes
    config.action_cable.worker_pool_size = Integer(ENV.fetch("CABLE_WORKERS", 16))

    # Active Record encryption (keys come from env; see .env.example)
    config.active_record.encryption.primary_key = ENV.fetch("AR_ENC_PRIMARY_KEY", "dev-primary-key-0123456789abcdef")
    config.active_record.encryption.deterministic_key = ENV.fetch("AR_ENC_DETERMINISTIC_KEY", "dev-determ-key-0123456789abcdef")
    config.active_record.encryption.key_derivation_salt = ENV.fetch("AR_ENC_KEY_DERIVATION_SALT", "dev-salt-0123456789abcdef")
  end
end
