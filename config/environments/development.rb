require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = ENV.fetch("RAILS_RELOAD", "1") == "1" # compose sets 0 for latency runs (file watching is slow on Docker for Windows)
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = true
  config.cache_store = :redis_cache_store, { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"), namespace: "cache" }
  config.active_support.deprecation = :log
  config.active_record.migration_error = :page_load
  config.active_record.verbose_query_logs = true
  config.active_record.query_log_tags_enabled = true
  # Database performance guard-rails (docs/db-performance.md): N+1 patterns raise in development.
  config.active_record.strict_loading_by_default = true
  config.active_record.strict_loading_mode = :n_plus_one_only
  config.action_controller.raise_on_missing_callback_actions = true
  config.action_cable.disable_request_forgery_protection = true
  config.hosts.clear
end
