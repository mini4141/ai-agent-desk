FactoryBot.define do
  factory :company do
    sequence(:name) { |n| "Company #{n}" }
    sequence(:slug) { |n| "company-#{n}" }
    locale { "ja" }
    settings { { "greeting" => "こんにちは", "greeting_v2" => "こんにちは！", "suggested_questions" => ["配送について"] } }
  end

  factory :user do
    company
    sequence(:email) { |n| "user#{n}@example.test" }
    name { "Tester" }
    password { "password123" }
    role { "operator" }
  end

  factory :conversation do
    company
    channel { "web_chat" }
    started_at { Time.current }
  end

  factory :tool do
    company
    name { "check_order_status" }
    description { "Look up an order" }
    endpoint { "http://company-backend.test/tools/check_order_status" }
    encrypted_secret { "shh" }
    params_schema { { "type" => "object", "properties" => { "order_id" => { "type" => "string" } } } }
  end
end
