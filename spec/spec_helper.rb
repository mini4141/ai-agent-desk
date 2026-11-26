RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.mock_with(:rspec) { |m| m.verify_partial_doubles = true }
  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.order = :random
end
