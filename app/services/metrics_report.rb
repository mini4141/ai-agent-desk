# Aggregates daily rollups into the dashboard numbers and the greeting_v2 vs control comparison.
class MetricsReport
  COUNTERS = %w[conversations deflected handoffs csat_sum csat_count handle_seconds handle_count tool_conversations].freeze

  def initialize(from:, to:, channel: nil, variant: nil)
    @scope = MetricRollup.where(day: from..to)
    @scope = @scope.where(channel:) if channel
    @scope = @scope.where(variant:) if variant
    @from = from
    @to = to
  end

  def call
    rows = @scope.to_a
    {
      from: @from, to: @to,
      totals: summarize(rows),
      by_variant: group(rows, &:variant),
      by_channel: group(rows, &:channel),
      by_day: rows.group_by(&:day).sort.map { |day, rs| { day:, **summarize(rs) } },
      experiment: experiment(rows)
    }
  end

  private

  def sum(rows) = COUNTERS.index_with { |k| rows.sum { |r| r.metrics[k].to_f } }

  def summarize(rows)
    s = sum(rows)
    n = s["conversations"]
    {
      conversations: n.to_i,
      deflection_rate: ratio(s["deflected"], n), handoff_rate: ratio(s["handoffs"], n),
      csat: s["csat_count"].positive? ? (s["csat_sum"] / s["csat_count"]).round(2) : nil,
      csat_responses: s["csat_count"].to_i,
      avg_handle_seconds: s["handle_count"].positive? ? (s["handle_seconds"] / s["handle_count"]).round : nil,
      tool_conversion: ratio(s["tool_conversations"], n)
    }
  end

  def ratio(a, b) = b.positive? ? (a / b).round(4) : nil

  def group(rows, &key) = rows.group_by(&key).transform_values { |rs| summarize(rs) }

  # Two-proportion z-test on deflection, greeting_v2 against control.
  def experiment(rows)
    control = sum(rows.select { |r| r.variant == "control" })
    treat = sum(rows.select { |r| r.variant == "greeting_v2" })
    n1 = control["conversations"]
    n2 = treat["conversations"]
    return { status: "insufficient_data" } if n1.zero? || n2.zero?

    p1 = control["deflected"] / n1
    p2 = treat["deflected"] / n2
    pooled = (control["deflected"] + treat["deflected"]) / (n1 + n2)
    se = Math.sqrt(pooled * (1 - pooled) * (1 / n1 + 1 / n2))
    z = se.zero? ? 0 : (p2 - p1) / se
    p_value = (2 * (1 - normal_cdf(z.abs))).round(4)
    {
      name: "greeting_v2",
      control: summarize(rows.select { |r| r.variant == "control" }),
      treatment: summarize(rows.select { |r| r.variant == "greeting_v2" }),
      deflection_delta_pp: ((p2 - p1) * 100).round(2),
      p_value:,
      sample_size: { control: n1.to_i, treatment: n2.to_i },
      note: sample_note(n1, n2, p_value)
    }
  end

  def sample_note(n1, n2, p_value)
    return "Sample too small (n=#{n1.to_i}/#{n2.to_i}); treat the delta as directional only." if [n1, n2].min < 200

    p_value < 0.05 ? "Difference is statistically significant at the 5% level." : "Not significant at the 5% level; keep collecting data."
  end

  def normal_cdf(z) = 0.5 * (1 + Math.erf(z / Math.sqrt(2)))
end
