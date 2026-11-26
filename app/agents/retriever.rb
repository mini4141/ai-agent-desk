# Per-company knowledge retrieval: pgvector cosine search, tenant-filtered by acts_as_tenant.
class Retriever
  Result = Struct.new(:chunks, :confidence, :ms, keyword_init: true)

  def call(query, k: 4)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    vector = Embedding.provider.embed(query)
    chunks = KnowledgeChunk.transaction do
      # pgvector 0.8: keep scanning the HNSW index until the tenant filter yields k rows.
      KnowledgeChunk.connection.execute("SET LOCAL hnsw.iterative_scan = relaxed_order")
      KnowledgeChunk.includes(:knowledge_source).nearest_neighbors(:embedding, vector, distance: "cosine").first(k)
    end
    confidence = chunks.empty? ? 0.0 : (1 - chunks.first.neighbor_distance).round(4)
    Result.new(chunks:, confidence:, ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round)
  end
end
