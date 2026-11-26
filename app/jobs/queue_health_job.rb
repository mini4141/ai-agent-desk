# Publishes Sidekiq queue latency and dead-set size as CloudWatch EMF metrics (alarm inputs).
class QueueHealthJob
  include Sidekiq::Job
  sidekiq_options queue: "critical", retry: 0

  def perform
    return unless ENV["EMF"] == "1"

    latency = Sidekiq::Queue.all.map(&:latency).max || 0
    Telemetry.emf("Sidekiq", { "QueueLatencySeconds" => latency.round(2), "DeadSetSize" => Sidekiq::DeadSet.new.size }, dims: { Service: "worker" })
  end
end
