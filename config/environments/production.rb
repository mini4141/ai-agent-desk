require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.public_file_server.enabled = true # serves the embeddable widget bundle (public/widget.js)
  config.cache_store = :redis_cache_store, { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"), namespace: "cache" }
  config.logger = ActiveSupport::TaggedLogging.logger($stdout) # CloudWatch reads container stdout
  $stdout.sync = true # container logs must not sit in a buffer
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.silence_healthcheck_path = "/up"
  config.active_support.report_deprecations = false
  config.active_record.dump_schema_after_migration = false
  config.action_cable.disable_request_forgery_protection = true # origin checked per-company in ApplicationCable::Connection
  config.hosts.clear
end
