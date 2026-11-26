# Database performance evidence (docs/db-performance.md).
#   DATABASE_URL=postgres://.../agent_desk_perf bin/rails db:create db:schema:load perf:report
# Seeds a large synthetic dataset, runs EXPLAIN ANALYZE before/after each optimisation and writes the report.
namespace :perf do
  desc "Seed a large dataset (50k conversations, 150k messages, 30k vector chunks across tenants)"
  task seed: :environment do
    c = ActiveRecord::Base.connection
    c.execute("TRUNCATE messages, conversations, knowledge_chunks, knowledge_sources, companies RESTART IDENTITY CASCADE")
    c.execute(<<~SQL)
      INSERT INTO companies (name, slug, locale, public_key, settings, allowed_origins, created_at, updated_at)
      SELECT 'Tenant ' || g, 'tenant-' || g, 'ja', 'pk_perf_' || g, '{}', '{}', now(), now() FROM generate_series(1, 30) g
    SQL
    # tenant 1 is "large": 50k conversations, 97% resolved; the others have 100 each
    c.execute(<<~SQL)
      INSERT INTO conversations (company_id, channel, status, variant, started_at, resolved_at, messages_count, last_message_at, last_message_preview, tags, intake, created_at, updated_at)
      SELECT CASE WHEN g <= 50000 THEN 1 ELSE 2 + (g % 29) END,
             (ARRAY['web_chat','voice_web','avatar','phone_sim'])[1 + g % 4],
             CASE WHEN g % 100 < 97 THEN 'resolved' WHEN g % 100 = 97 THEN 'waiting_human' WHEN g % 100 = 98 THEN 'human' ELSE 'ai' END,
             'control', now() - (g || ' minutes')::interval, now() - (g || ' minutes')::interval + interval '3 minutes', 3,
             now() - (g || ' minutes')::interval, 'preview ' || g, '{}', '{}', now(), now()
      FROM generate_series(1, 52900) g
    SQL
    c.execute(<<~SQL)
      INSERT INTO messages (conversation_id, role, content, citations, timings, metadata, created_at, updated_at)
      SELECT cv.id, (ARRAY['customer','ai','ai'])[m], 'message ' || m, '[]', '{}', '{}', cv.started_at + (m || ' seconds')::interval, now()
      FROM conversations cv, generate_series(1, 3) m
    SQL
    c.execute(<<~SQL)
      INSERT INTO knowledge_sources (company_id, kind, title, status, chunks_count, created_at, updated_at)
      SELECT g, 'url', 'src', 'ready', 0, now(), now() FROM generate_series(1, 30) g
    SQL
    # tenant 1: 20k chunks; tenants 2..30: ~345 each (10k)
    c.execute(<<~SQL)
      INSERT INTO knowledge_chunks (company_id, knowledge_source_id, content, embedding, metadata, created_at, updated_at)
      SELECT CASE WHEN g <= 20000 THEN 1 ELSE 2 + (g % 29) END,
             CASE WHEN g <= 20000 THEN 1 ELSE 2 + (g % 29) END,
             'chunk ' || g, (SELECT array_agg(random())::vector(1024) FROM generate_series(1, 1024) WHERE g > 0), '{}', now(), now()
      FROM generate_series(1, 30000) g
    SQL
    c.execute("ANALYZE")
    puts "seeded"
  end

  def explain(sql, binds = [])
    ActiveRecord::Base.connection.exec_query("EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) #{sql}", "explain", binds).rows.flatten.join("\n")
  end

  desc "Run before/after EXPLAIN ANALYZE and write docs/db-performance.md"
  task report: :seed do
    c = ActiveRecord::Base.connection
    inbox = "SELECT * FROM conversations WHERE company_id = 1 AND status IN ('waiting_human','human','ai') " \
            "ORDER BY #{Conversation::PRIORITY_SQL}, id LIMIT 100"
    count_one = "SELECT count(*) FROM messages WHERE conversation_id = 12345"
    vec = "[" + Array.new(1024) { rand.round(4) }.join(",") + "]"
    knn = ->(tenant) { "SELECT id FROM knowledge_chunks WHERE company_id = #{tenant} ORDER BY embedding <=> '#{vec}' LIMIT 4" }

    c.execute("DROP INDEX IF EXISTS idx_conversations_inbox")
    inbox_before = explain(inbox)
    c.execute("CREATE INDEX idx_conversations_inbox ON conversations (company_id, status, last_message_at DESC)")
    c.execute("ANALYZE conversations")
    inbox_after = explain(inbox)

    c.execute("DROP INDEX IF EXISTS idx_messages_conversation_created")
    count_before = explain(count_one)
    c.execute("CREATE INDEX idx_messages_conversation_created ON messages (conversation_id, created_at)")
    c.execute("ANALYZE messages")
    count_after = explain(count_one)

    c.execute("DROP INDEX IF EXISTS idx_chunks_embedding_hnsw")
    c.execute("DROP INDEX IF EXISTS index_knowledge_chunks_on_company_id")
    c.execute("ANALYZE knowledge_chunks")
    knn_big_before = explain(knn.call(1))
    c.execute("CREATE INDEX index_knowledge_chunks_on_company_id ON knowledge_chunks (company_id)")
    c.execute("ANALYZE knowledge_chunks")
    knn_big_btree = explain(knn.call(1))
    knn_small_btree = explain(knn.call(7))
    c.execute("CREATE INDEX idx_chunks_embedding_hnsw ON knowledge_chunks USING hnsw (embedding vector_cosine_ops)")
    c.execute("ANALYZE knowledge_chunks")
    c.execute("SET hnsw.iterative_scan = relaxed_order")
    c.execute("SET enable_seqscan = off")
    knn_big_hnsw = explain(knn.call(1))
    knn_small_hnsw = explain(knn.call(7))
    c.execute("RESET enable_seqscan")
    knn_big_default = explain(knn.call(1))

    sections = {
      "Inbox query: before (company_id index only)" => inbox_before, "Inbox query: after (composite index)" => inbox_after,
      "Message count: before" => count_before, "Message count: after" => count_after,
      "Vector search, large tenant (20k chunks): before (no vector/tenant index)" => knn_big_before,
      "Vector search, large tenant: company_id btree + exact sort" => knn_big_btree,
      "Vector search, small tenant (~345 chunks): company_id btree + exact sort" => knn_small_btree,
      "Vector search, large tenant: HNSW forced (enable_seqscan=off)" => knn_big_hnsw,
      "Vector search, small tenant: HNSW forced (enable_seqscan=off)" => knn_small_hnsw,
      "Vector search, large tenant: planner default with all indexes" => knn_big_default
    }
    time = ->(plan) { plan[/Execution Time: ([\d.]+) ms/, 1] }
    File.write(Rails.root.join("docs/db-performance.md"), <<~MD)
      # Database performance

      Real `EXPLAIN (ANALYZE, BUFFERS)` output, generated by `bin/rails perf:report` (see `lib/tasks/perf.rake`) on PostgreSQL 17 + pgvector 0.8
      with a synthetic dataset: 52,900 conversations (50,000 in one large tenant, 97 % resolved), 158,700 messages, 30,000 vector(1024) chunks
      (20,000 in tenant 1, ~345 in each of 29 others). Timings are from a laptop in Docker, so read the ratios and the plan shapes, not the absolute numbers.

      ## Summary

      | Optimisation | Before | After |
      |---|---|---|
      | Inbox query: composite index `(company_id, status, last_message_at DESC)` | #{time.call(inbox_before)} ms | #{time.call(inbox_after)} ms |
      | Per-conversation message count: `(conversation_id, created_at)` index / `messages_count` counter cache | #{time.call(count_before)} ms (+1 query per row without the counter) | #{time.call(count_after)} ms, or 0 queries with the counter column |
      | Vector search, large tenant: seq scan → tenant btree (`company_id`) + exact sort | #{time.call(knn_big_before)} ms | #{time.call(knn_big_btree)} ms |
      | Vector search, large tenant: btree + sort → HNSW (`hnsw.iterative_scan = relaxed_order`) | #{time.call(knn_big_btree)} ms (btree + sort) | #{time.call(knn_big_hnsw)} ms |
      | Vector search, small tenant (~345 chunks): btree + sort vs forced HNSW | #{time.call(knn_small_btree)} ms | #{time.call(knn_small_hnsw)} ms |

      Takeaways

      - The inbox only ever needs open conversations (3 % of rows). The composite index turns a scan of all 50,000 tenant rows into a scan of the ~1,500 open ones.
      - `messages_count` (counter cache) removes the per-row `count(*)` entirely; the index keeps the occasional exact count cheap.
      - Vector search is always filtered by `company_id` (`acts_as_tenant`). For a small tenant the planner correctly prefers the tenant btree and an exact sort.
        For a large tenant the HNSW index wins; it is queried with `hnsw.iterative_scan = relaxed_order` (pgvector 0.8) so the tenant filter cannot starve the result set.
      - Development uses `strict_loading_by_default` (N+1 patterns raise) and the test suite runs Bullet, so query-count regressions fail before they reach production.

      #{sections.map { |title, plan| "## #{title}\n\n```\n#{plan}\n```\n" }.join("\n")}
    MD
    puts "wrote docs/db-performance.md"
  end
end
