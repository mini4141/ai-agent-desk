# p50/p95 per stage and channel from messages.timings, against the latency budget (CLAUDE.md §11).
class LatencyReport
  STAGES = %w[stt_ms retrieval_ms llm_first_token_ms llm_total_ms tts_first_audio_ms end_to_end_ms].freeze
  BUDGET_MS = { "web_chat" => 1500, "voice_web" => 2500, "avatar" => 2500, "phone_sim" => 2500 }.freeze

  def initialize(days: 7)
    @days = days
  end

  def call
    cols = STAGES.flat_map do |s|
      [0.5, 0.95].map do |q|
        "percentile_cont(#{q}) WITHIN GROUP (ORDER BY (m.timings->>'#{s}')::float) FILTER (WHERE m.timings ? '#{s}') AS #{s}_p#{(q * 100).to_i}"
      end
    end
    sql = <<~SQL.squish
      SELECT c.channel, count(*) AS turns,
             count(*) FILTER (WHERE m.timings->>'cache_hit' = 'true') AS cache_hits,
             #{cols.join(', ')}
      FROM messages m JOIN conversations c ON c.id = m.conversation_id
      WHERE c.company_id = $1 AND m.role = 'ai' AND m.created_at > $2 AND m.timings ? 'end_to_end_ms'
      GROUP BY c.channel ORDER BY c.channel
    SQL
    rows = ActiveRecord::Base.connection.exec_query(sql, "latency", [ActsAsTenant.current_tenant.id, @days.days.ago])
    { budget_ms: BUDGET_MS, stages: STAGES, channels: rows.map { |r| channel_row(r) } }
  end

  private

  def channel_row(row)
    {
      channel: row["channel"], turns: row["turns"], cache_hit_rate: (row["cache_hits"].to_f / row["turns"]).round(3),
      budget_ms: BUDGET_MS[row["channel"]],
      stages: STAGES.to_h { |s| [s, { p50: row["#{s}_p50"]&.round, p95: row["#{s}_p95"]&.round }] }
    }
  end
end
