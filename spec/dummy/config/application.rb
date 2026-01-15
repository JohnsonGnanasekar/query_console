require 'rails'
require 'action_controller/railtie'
require 'active_record/railtie'

Bundler.require(*Rails.groups)
require 'query_console'

module Dummy
  class Application < Rails::Application
    config.load_defaults 8.0
    config.eager_load = false
    config.api_only = false
    
    # Required for session/CSRF
    config.session_store :cookie_store, key: '_query_console_session'
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore, config.session_options
  end
end
