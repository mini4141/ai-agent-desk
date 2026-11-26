source "https://rubygems.org"

gem "rails", "~> 8.1.4"
gem "pg", "~> 1.5"
gem "puma", ">= 6.4"
gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[windows jruby]

# Auth / security
gem "bcrypt", "~> 3.1"
gem "jwt", "~> 2.9"
gem "pundit", "~> 2.4"
gem "rack-attack", "~> 6.7"
gem "rack-cors", "~> 2.0"

# Tenancy, flags, jobs, cache, realtime
gem "acts_as_tenant", "~> 1.0"
gem "flipper", "~> 1.3"
gem "flipper-active_record", "~> 1.3"
gem "sidekiq", "~> 8.0"
gem "sidekiq-cron", "~> 2.0"
gem "redis", "~> 5.3"
gem "redis-client", "~> 0.22"

# Vector search
gem "neighbor", "~> 0.5"

# Ingestion
gem "nokogiri", "~> 1.18"
gem "pdf-reader", "~> 2.12"

# AWS (used when *_PROVIDER=bedrock/aws)
gem "aws-sdk-bedrockruntime", "~> 1.0"
gem "aws-sdk-polly", "~> 1.0"
gem "aws-sdk-transcribestreamingservice", "~> 1.0"
gem "aws-sdk-s3", "~> 1.0"
gem "http-2", "~> 1.0"

# Observability
gem "lograge", "~> 0.14"
gem "opentelemetry-sdk", "~> 1.6"
gem "opentelemetry-exporter-otlp", "~> 0.29"
gem "opentelemetry-instrumentation-all", "~> 0.74"
gem "prometheus-client", "~> 4.2"

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "rspec-rails", "~> 7.1"
  gem "factory_bot_rails", "~> 6.4"
  gem "rspec_junit_formatter", "~> 0.6"
  gem "bullet", "~> 8.0"
  gem "bundler-audit", require: false
end

group :test do
  gem "webmock", "~> 3.24"
end
