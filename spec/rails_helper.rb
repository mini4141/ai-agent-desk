ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("Rails is running in production!") if Rails.env.production?
require "rspec/rails"
require "webmock/rspec"
require "sidekiq/testing"

Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.include FactoryBot::Syntax::Methods
  config.include TenantHelpers
  config.before do
    ActsAsTenant.current_tenant = nil
    Rails.cache.clear
    Sidekiq::Job.clear_all
  end
end
