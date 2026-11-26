require "prometheus/client"
require "prometheus/client/data_stores/direct_file_store"
require "prometheus/middleware/exporter"

# Multi-process safe (puma cluster mode): every worker writes to one file-backed store.
role = ENV.fetch("PROM_ROLE", "web")
dir = Rails.root.join("tmp/prometheus-#{role}")
FileUtils.mkdir_p(dir)
Prometheus::Client.config.data_store = Prometheus::Client::DataStores::DirectFileStore.new(dir: dir.to_s)

Rails.application.config.middleware.use Prometheus::Middleware::Exporter
