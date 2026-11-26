module ApplicationCable
  class Channel < ActionCable::Channel::Base
    private

    # Channel actions run on Action Cable worker threads, so tenant and trace context are set per action.
    def in_company(company, trace: nil, &block)
      run = ->(*) { ActsAsTenant.with_tenant(company, &block) }
      return run.call unless trace.present?

      OpenTelemetry::Context.with_current(OpenTelemetry.propagation.extract({ "traceparent" => trace }), &run)
    end
  end
end
