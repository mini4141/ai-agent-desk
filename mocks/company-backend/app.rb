require "sinatra/base"
require "json"
require "openssl"

# Mock company backend: order lookup + callback booking (HMAC-signed tool endpoints),
# plus the bundled demo help sites served as static files under /sites.
class CompanyBackend < Sinatra::Base
  set :bind, "0.0.0.0"
  set :port, 4567
  set :host_authorization, { permitted_hosts: [] } # reachable by service name inside Docker/ECS
  set :public_folder, File.join(__dir__, "public")
  set :static_cache_control, [:public, max_age: 60]

  SECRET = ENV.fetch("TOOL_HMAC_SECRET", "dev-tool-secret")
  ORDERS = {
    "A-1023" => { status: "出荷済み", eta: "11月28日", carrier: "ヤマト運輸", status_en: "Shipped" },
    "A-1024" => { status: "配送準備中", eta: "12月2日", carrier: "佐川急便", status_en: "Preparing" },
    "H-2001" => { status: "Shipped", eta: "Dec 1", carrier: "UPS", status_en: "Shipped" },
    "H-2002" => { status: "Delivered", eta: "Nov 25", carrier: "FedEx", status_en: "Delivered" }
  }.freeze

  helpers do
    def signed_json
      body = request.body.read
      expected = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', SECRET, body)}"
      halt 401, { error: "bad_signature" }.to_json unless Rack::Utils.secure_compare(expected, request.env["HTTP_X_SIGNATURE"].to_s)
      JSON.parse(body)
    end
  end

  before { content_type :json unless request.path.start_with?("/sites") }

  get("/healthz") { { ok: true }.to_json }

  post "/tools/check_order_status" do
    id = signed_json["order_id"].to_s.upcase
    order = ORDERS[id] or halt 404, { error: "order_not_found", order_id: id }.to_json
    status = id.start_with?("H") ? order[:status_en] : order[:status]
    { order_id: id, status: status, eta: order[:eta], carrier: order[:carrier] }.to_json
  end

  post "/tools/book_callback" do
    data = signed_json
    halt 422, { error: "phone_and_time_required" }.to_json unless data["phone"] && data["time"]
    { confirmation: "CB-#{rand(1000..9999)}", phone_last4: data["phone"].to_s[-4..], time: data["time"] }.to_json
  end

  post "/webhooks/conversation" do
    signed_json
    { received: true }.to_json
  end

  # /sites/<slug>/<page>.html is served from public_folder; "/sites/<slug>/" -> index.html
  get %r{/sites/([\w-]+)/?} do |slug|
    send_file File.join(settings.public_folder, "sites", slug, "index.html")
  end
end
