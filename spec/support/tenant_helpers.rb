module TenantHelpers
  # Builds records inside a company tenant (acts_as_tenant requires one for any query).
  def in_tenant(company, &block) = ActsAsTenant.with_tenant(company, &block)

  def bearer(user) = { "Authorization" => "Bearer #{AuthToken.encode({ kind: 'user', sub: user.id })}" }

  # Stores FAQ chunks with the offline mock embeddings so retrieval works in specs.
  def seed_knowledge(company, pairs, title: "配送について")
    in_tenant(company) do
      source = KnowledgeSource.create!(kind: "url", url: "http://x.test/#{SecureRandom.hex(3)}", title:, status: "ready", chunks_count: pairs.size)
      pairs.each { |q, a| source.knowledge_chunks.create!(content: "#{q}\n#{a}", embedding: Embedding.provider.embed("#{q} #{a}")) }
      source
    end
  end
end
