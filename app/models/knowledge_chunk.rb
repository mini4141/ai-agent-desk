class KnowledgeChunk < ApplicationRecord
  acts_as_tenant :company
  belongs_to :knowledge_source
  has_neighbors :embedding
end
