# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_26_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "companies", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "locale", default: "ja", null: false
    t.string "public_key", null: false
    t.string "api_key_digest"
    t.text "webhook_secret"
    t.string "allowed_origins", default: [], null: false, array: true
    t.jsonb "settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["public_key"], name: "index_companies_on_public_key", unique: true
    t.index ["slug"], name: "index_companies_on_slug", unique: true
  end

  create_table "conversations", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "channel", default: "web_chat", null: false
    t.string "status", default: "ai", null: false
    t.bigint "assignee_id"
    t.string "variant", default: "control", null: false
    t.string "visitor_id"
    t.string "language"
    t.string "mode", default: "chat", null: false
    t.integer "csat"
    t.datetime "started_at", null: false
    t.datetime "resolved_at"
    t.integer "messages_count", default: 0, null: false
    t.datetime "last_message_at"
    t.string "last_message_preview"
    t.text "draft_reply"
    t.string "tags", default: [], null: false, array: true
    t.jsonb "intake", default: {}, null: false
    t.string "escalation_reason"
    t.boolean "tool_called", default: false, null: false
    t.boolean "human_involved", default: false, null: false
    t.boolean "simulated", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id"], name: "index_conversations_on_assignee_id"
    t.index ["company_id", "started_at"], name: "index_conversations_on_company_id_and_started_at"
    t.index ["company_id", "status", "last_message_at"], name: "idx_conversations_inbox", order: { last_message_at: :desc }
    t.index ["company_id"], name: "index_conversations_on_company_id"
  end

  create_table "flipper_features", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.string "feature_key", null: false
    t.string "key", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "knowledge_chunks", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "knowledge_source_id", null: false
    t.text "content", null: false
    t.vector "embedding", limit: 1024
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_knowledge_chunks_on_company_id"
    t.index ["embedding"], name: "idx_chunks_embedding_hnsw", opclass: :vector_cosine_ops, using: :hnsw
    t.index ["knowledge_source_id"], name: "index_knowledge_chunks_on_knowledge_source_id"
  end

  create_table "knowledge_sources", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "kind", default: "url", null: false
    t.string "title"
    t.string "url"
    t.string "s3_key"
    t.string "status", default: "pending", null: false
    t.integer "chunks_count", default: 0, null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_knowledge_sources_on_company_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.string "role", null: false
    t.text "content", default: "", null: false
    t.jsonb "citations", default: [], null: false
    t.jsonb "timings", default: {}, null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "created_at"], name: "idx_messages_conversation_created"
  end

  create_table "metric_rollups", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.date "day", null: false
    t.string "channel", null: false
    t.string "variant", null: false
    t.jsonb "metrics", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "day", "channel", "variant"], name: "idx_rollups_unique", unique: true
    t.index ["company_id"], name: "index_metric_rollups_on_company_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "tools", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "name", null: false
    t.text "description", null: false
    t.jsonb "params_schema", default: {}, null: false
    t.string "endpoint", null: false
    t.text "encrypted_secret"
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "name"], name: "index_tools_on_company_id_and_name", unique: true
    t.index ["company_id"], name: "index_tools_on_company_id"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "email", null: false
    t.string "name"
    t.string "password_digest", null: false
    t.string "role", default: "operator", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "conversations", "companies"
  add_foreign_key "conversations", "users", column: "assignee_id"
  add_foreign_key "knowledge_chunks", "companies"
  add_foreign_key "knowledge_chunks", "knowledge_sources"
  add_foreign_key "knowledge_sources", "companies"
  add_foreign_key "messages", "conversations"
  add_foreign_key "metric_rollups", "companies"
  add_foreign_key "sessions", "users"
  add_foreign_key "tools", "companies"
  add_foreign_key "users", "companies"
end
