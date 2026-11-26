require "fileutils"

threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
threads threads_count, threads_count
port ENV.fetch("PORT", 3000)
workers ENV.fetch("WEB_CONCURRENCY", 0).to_i
plugin :tmp_restart

# Prometheus metrics are shared between forked workers through files; start each boot from a clean directory.
FileUtils.rm_rf("tmp/prometheus-web")
FileUtils.mkdir_p("tmp/prometheus-web")
