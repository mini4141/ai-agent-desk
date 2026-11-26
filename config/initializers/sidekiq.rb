redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

Sidekiq.configure_client { |c| c.redis = redis }

Sidekiq.configure_server do |c|
  c.redis = redis
  # Nightly rollup (SPECS F9) and queue-health metrics for the CloudWatch alarms.
  Sidekiq::Cron::Job.load_from_hash(
    "nightly_rollup" => { "cron" => "10 15 * * *", "class" => "MetricsRollupJob", "queue" => "low" },
    "queue_health" => { "cron" => "* * * * *", "class" => "QueueHealthJob", "queue" => "critical" }
  )
end
