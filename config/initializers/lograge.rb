Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new
  config.lograge.custom_options = lambda do |event|
    { request_id: event.payload[:request_id], tenant: ActsAsTenant.current_tenant&.id }.compact
  end
  config.log_level = ENV["RAILS_LOG_LEVEL"] || (Rails.env.test? ? :warn : :info)

  unless Rails.env.test?
    # Structured JSON lines; customer PII (emails, phone numbers) never reaches logs.
    config.after_initialize do
      formatter = lambda do |sev, time, _prog, msg|
        line = { level: sev, time: time.utc.iso8601(3), msg: PiiRedactor.redact(msg.is_a?(String) ? msg : msg.inspect) }
        "#{line.to_json}
"
      end
      formatter.extend(ActiveSupport::TaggedLogging::Formatter) # keep Rails' tagged-logging contract
      Rails.logger.formatter = formatter
    end
  end
end
