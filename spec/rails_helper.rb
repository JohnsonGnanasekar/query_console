require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'

require File.expand_path('../spec/dummy/config/environment', __dir__)

abort("The Rails environment is running in production mode!") if Rails.env.production?

require 'rspec/rails'

# Load the engine
require 'query_console'

RSpec.configure do |config|
  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  # Reset configuration before each test
  config.before(:each) do
    QueryConsole.reset_configuration!
  end
end
