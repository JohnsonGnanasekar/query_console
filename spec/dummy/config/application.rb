require 'rails/all'

Bundler.require(*Rails.groups)
require 'query_console'

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.eager_load = false
  end
end
