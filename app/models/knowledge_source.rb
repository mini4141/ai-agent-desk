class KnowledgeSource < ApplicationRecord
  acts_as_tenant :company
  has_many :knowledge_chunks, dependent: :delete_all

  enum :kind, { url: "url", markdown: "markdown", pdf: "pdf" }, validate: true
  enum :status, { pending: "pending", processing: "processing", ready: "ready", failed: "failed" }, validate: true

  def as_api = { id:, kind:, title:, url:, status:, chunks_count:, error: }
end
