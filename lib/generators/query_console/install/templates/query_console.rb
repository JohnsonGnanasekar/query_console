# QueryConsole Configuration
#
# This initializer configures the QueryConsole engine for your application.
# By default, the console is ONLY enabled in development environment.

QueryConsole.configure do |config|
  # Environments where the console is enabled
  # Default: ["development"]
  # Uncomment to enable in additional environments (use with caution!)
  # config.enabled_environments = %w[development staging]

  # Authorization hook - REQUIRED for security
  # This lambda/proc receives the controller and must return true to allow access
  # Default: nil (denies all access - you MUST configure this)
  #
  # Example with Devise:
  # config.authorize = ->(controller) {
  #   controller.current_user&.admin?
  # }
  #
  # Example with basic authentication:
  # config.authorize = ->(controller) {
  #   controller.authenticate_or_request_with_http_basic do |username, password|
  #     username == "admin" && password == Rails.application.credentials.query_console_password
  #   end
  # }
  #
  # For development without authentication (NOT RECOMMENDED FOR PRODUCTION):
  # config.authorize = ->(_controller) { true }

  # Track who ran each query (for audit logs)
  # Default: ->(_controller) { "unknown" }
  #
  # config.current_actor = ->(controller) {
  #   controller.current_user&.email || "anonymous"
  # }

  # Maximum number of rows to return
  # Default: 500
  # config.max_rows = 1000

  # Query timeout in milliseconds
  # Default: 3000 (3 seconds)
  # config.timeout_ms = 5000

  # Forbidden SQL keywords (in addition to defaults)
  # Default includes: update, delete, insert, drop, alter, create, grant, revoke, truncate, etc.
  # config.forbidden_keywords += %w[your_custom_keyword]

  # Allowed query starting keywords
  # Default: %w[select with]
  # config.allowed_starts_with = %w[select with explain]
end

# IMPORTANT: Mount the engine in your routes.rb:
#
# Rails.application.routes.draw do
#   mount QueryConsole::Engine, at: "/query_console"
# end
#
# Then visit: http://localhost:3000/query_console
