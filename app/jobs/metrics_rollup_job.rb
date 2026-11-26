# Daily rollups per company, channel and experiment variant (SPECS F9).
# Runs nightly via sidekiq-cron and on demand from the dashboard.
class MetricsRollupJob
  include Sidekiq::Job
  include TenantJob
  sidekiq_options queue: "low", retry: 3

  SQL = <<~SQL.squish.freeze
    SELECT channel, variant,
           count(*) AS conversations,
           count(*) FILTER (WHERE status = 'resolved' AND NOT human_involved) AS deflected,
           count(*) FILTER (WHERE human_involved) AS handoffs,
           coalesce(sum(csat), 0) AS csat_sum, count(csat) AS csat_count,
           coalesce(sum(extract(epoch FROM resolved_at - started_at)) FILTER (WHERE resolved_at IS NOT NULL), 0) AS handle_seconds,
           count(resolved_at) AS handle_count,
           count(*) FILTER (WHERE tool_called) AS tool_conversations
    FROM conversations
    WHERE company_id = $1 AND started_at >= $2 AND started_at < $3
    GROUP BY channel, variant
  SQL

  def perform(days = 2, company_id = nil)
    companies = company_id ? Company.where(id: company_id) : Company.all
    companies.find_each do |company|
      with_company(company.id) do
        (0...days.to_i).each { |offset| rollup_day(company, Time.zone.today - offset) }
      end
    end
  end

  private

  def rollup_day(company, day)
    from = day.beginning_of_day
    rows = ActiveRecord::Base.connection.exec_query(SQL, "rollup", [company.id, from, from + 1.day])
    rows.each do |row|
      rollup = MetricRollup.find_or_initialize_by(company:, day:, channel: row["channel"], variant: row["variant"])
      rollup.metrics = row.except("channel", "variant").transform_values { |v| v.is_a?(BigDecimal) ? v.to_f : v.to_i }
      rollup.save!
    end
  end
end
