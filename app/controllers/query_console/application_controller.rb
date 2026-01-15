module QueryConsole
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception

    before_action :ensure_enabled!
    before_action :authorize_access!

    private

    def ensure_enabled!
      config = QueryConsole.configuration
      
      unless config.enabled_environments.map(&:to_s).include?(Rails.env.to_s)
        raise ActionController::RoutingError, "Not Found"
      end
    end

    def authorize_access!
      config = QueryConsole.configuration
      
      # Default deny if no authorize hook is configured
      if config.authorize.nil?
        Rails.logger.warn("[QueryConsole] Access denied: No authorization hook configured")
        raise ActionController::RoutingError, "Not Found"
      end

      # Call the authorization hook
      unless config.authorize.call(self)
        Rails.logger.warn("[QueryConsole] Access denied by authorization hook")
        raise ActionController::RoutingError, "Not Found"
      end
    end
  end
end
