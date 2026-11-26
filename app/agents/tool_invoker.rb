require "net/http"
require "openssl"

# Calls a company-configured HTTP workflow tool, signing the JSON body with the tool's HMAC secret.
class ToolInvoker
  def call(tool, input)
    body = input.to_json
    signature = OpenSSL::HMAC.hexdigest("SHA256", tool.encrypted_secret.to_s, body)
    uri = URI(tool.endpoint)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = http.read_timeout = 5
    res = http.post(uri.request_uri, body, "Content-Type" => "application/json", "X-Signature" => "sha256=#{signature}")
    parsed = JSON.parse(res.body)
    res.is_a?(Net::HTTPSuccess) ? parsed : { "error" => parsed["error"] || "http_#{res.code}" }
  rescue StandardError => e
    { "error" => e.class.name, "message" => e.message }
  end
end
