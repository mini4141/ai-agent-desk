class CreateCore < ActiveRecord::Migration[8.1]
  def change
    enable_extension "vector"

    create_table :companies do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :locale, null: false, default: "ja"
      t.string :public_key, null: false
      t.string :api_key_digest
      t.text :webhook_secret # Active Record encrypted
      t.string :allowed_origins, array: true, default: [], null: false
      t.jsonb :settings, null: false, default: {}
      t.timestamps
    end
    add_index :companies, :slug, unique: true
    add_index :companies, :public_key, unique: true

    create_table :users do |t|
      t.references :company, null: false, foreign_key: true
      t.string :email, null: false
      t.string :name
      t.string :password_digest, null: false
      t.string :role, null: false, default: "operator"
      t.timestamps
    end
    add_index :users, :email, unique: true

    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end

    create_table :knowledge_sources do |t|
      t.references :company, null: false, foreign_key: true
      t.string :kind, null: false, default: "url" # url | markdown | pdf
      t.string :title
      t.string :url
      t.string :s3_key
      t.string :status, null: false, default: "pending"
      t.integer :chunks_count, null: false, default: 0
      t.text :error
      t.timestamps
    end

    create_table :knowledge_chunks do |t|
      t.references :company, null: false, foreign_key: true
      t.references :knowledge_source, null: false, foreign_key: true
      t.text :content, null: false
      t.vector :embedding, limit: 1024
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    # Tenant filter + cosine HNSW (docs/db-performance.md)
    add_index :knowledge_chunks, :embedding, using: :hnsw, opclass: :vector_cosine_ops, name: "idx_chunks_embedding_hnsw"

    create_table :tools do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description, null: false
      t.jsonb :params_schema, null: false, default: {}
      t.string :endpoint, null: false
      t.text :encrypted_secret # Active Record encrypted HMAC secret
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end
    add_index :tools, %i[company_id name], unique: true

    create_table :conversations do |t|
      t.references :company, null: false, foreign_key: true
      t.string :channel, null: false, default: "web_chat"
      t.string :status, null: false, default: "ai"
      t.references :assignee, foreign_key: { to_table: :users }
      t.string :variant, null: false, default: "control"
      t.string :visitor_id
      t.string :language
      t.string :mode, null: false, default: "chat" # chat | interview
      t.integer :csat
      t.datetime :started_at, null: false
      t.datetime :resolved_at
      t.integer :messages_count, null: false, default: 0
      t.datetime :last_message_at
      t.string :last_message_preview
      t.text :draft_reply
      t.string :tags, array: true, default: [], null: false
      t.jsonb :intake, null: false, default: {}
      t.string :escalation_reason
      t.boolean :tool_called, null: false, default: false
      t.boolean :human_involved, null: false, default: false
      t.boolean :simulated, null: false, default: false
      t.timestamps
    end
    # Inbox query: open conversations by status, newest activity first (docs/db-performance.md)
    add_index :conversations, %i[company_id status last_message_at], order: { last_message_at: :desc }, name: "idx_conversations_inbox"
    add_index :conversations, %i[company_id started_at]

    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true, index: false
      t.string :role, null: false
      t.text :content, null: false, default: ""
      t.jsonb :citations, null: false, default: []
      t.jsonb :timings, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :messages, %i[conversation_id created_at], name: "idx_messages_conversation_created"

    create_table :metric_rollups do |t|
      t.references :company, null: false, foreign_key: true
      t.date :day, null: false
      t.string :channel, null: false
      t.string :variant, null: false
      t.jsonb :metrics, null: false, default: {}
      t.timestamps
    end
    add_index :metric_rollups, %i[company_id day channel variant], unique: true, name: "idx_rollups_unique"

    # Flipper (feature flags / experiments)
    create_table :flipper_features do |t|
      t.string :key, null: false
      t.timestamps null: false
    end
    add_index :flipper_features, :key, unique: true

    create_table :flipper_gates do |t|
      t.string :feature_key, null: false
      t.string :key, null: false
      t.text :value
      t.timestamps null: false
    end
    add_index :flipper_gates, %i[feature_key key value], unique: true, length: { value: 255 }
  end
end
