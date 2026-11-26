require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = ENV["CI"].present?
  config.consider_all_requests_local = true
  config.cache_store = :memory_store
  config.action_dispatch.show_exceptions = :rescuable
  config.active_support.deprecation = :stderr
  config.action_controller.raise_on_missing_callback_actions = true
  config.action_cable.disable_request_forgery_protection = true
  config.active_job.queue_adapter = :test
  config.hosts.clear

  config.after_initialize do
    Bullet.enable = true
    Bullet.raise = true
    Bullet.unused_eager_loading_enable = false
    Bullet.counter_cache_enable = false
  end
end
