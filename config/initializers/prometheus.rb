require "prometheus/middleware/exporter"
Rails.application.config.middleware.use Prometheus::Middleware::Exporter
