require "net/http"

# Fetch/parse a knowledge source, chunk it, embed each chunk and store it in pgvector.
class IngestSourceJob
  include Sidekiq::Job
  include TenantJob
  sidekiq_options queue: "default", retry: 3

  class DisallowedHost < StandardError; end

  def perform(source_id, company_id)
    with_company(company_id) do
      source = KnowledgeSource.find(source_id)
      source.update!(status: "processing", error: nil)
      source.knowledge_chunks.delete_all
      document = parse(source)
      document.chunks.each do |content|
        source.knowledge_chunks.create!(content:, embedding: Embedding.provider.embed(content))
      end
      source.update!(status: "ready", title: source.title.presence || document.title, chunks_count: document.chunks.size)
    rescue StandardError => e
      source&.update(status: "failed", error: e.message.truncate(300))
      raise
    end
  end

  private

  def parse(source)
    case source.kind
    when "url" then Chunker.html(fetch(source.url))
    when "markdown" then Chunker.markdown(BlobStore.read(source.s3_key).force_encoding("UTF-8"))
    when "pdf" then Chunker.pdf(BlobStore.read(source.s3_key))
    end
  end

  # Only the bundled demo sites may be crawled.
  def fetch(url)
    uri = URI(url)
    allowed = ENV.fetch("INGEST_ALLOWED_HOSTS", "company-backend,localhost").split(",")
    raise DisallowedHost, uri.host unless allowed.include?(uri.host)

    res = Net::HTTP.get_response(uri)
    raise "fetch failed: #{res.code}" unless res.is_a?(Net::HTTPSuccess)

    res.body.force_encoding("UTF-8")
  end
end
