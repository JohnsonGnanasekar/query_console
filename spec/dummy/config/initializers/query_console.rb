# QueryConsole configuration for testing
QueryConsole.configure do |config|
  # Enable in development and test
  config.enabled_environments = %w[development test]
  
  # For testing: allow all access (no authentication)
  config.authorize = ->(_controller) { true }
  
  # Track test actor
  config.current_actor = ->(_controller) { "test_user" }
  
  # Test limits
  config.max_rows = 100
  config.timeout_ms = 30000  # 30 seconds - more generous for development
end
