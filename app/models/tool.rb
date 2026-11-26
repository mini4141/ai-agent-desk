class Tool < ApplicationRecord
  acts_as_tenant :company
  encrypts :encrypted_secret

  validates :name, :description, :endpoint, presence: true

  # Tool definition in the shape Bedrock Converse (and the mock LLM) expects.
  def to_spec
    { tool_spec: { name:, description:, input_schema: { json: params_schema } } }
  end

  def as_api = { id:, name:, description:, params_schema:, endpoint:, enabled: }
end
