module QueryConsole
  class ApplicationController < ActionController::Base
    # Rails 8 CSRF protection - use null_session for Turbo Frame requests
    protect_from_forgery with: :exception, prepend: true
    
    # Skip CSRF for Turbo Frame requests (Turbo handles it via meta tags)
    skip_forgery_protection if: -> { request.headers['Turbo-Frame'].present? }

    before_action :ensure_enabled!
    before_action :authorize_access!

    private

    def ensure_enabled!
      config = QueryConsole.configuration
      
      unless config.enabled_environments.map(&:to_s).include?(Rails.env.to_s)
        render plain: "Not Found", status: :not_found
        return false
      end
    end

    def authorize_access!
      config = QueryConsole.configuration
      
      # Default deny if no authorize hook is configured
      if config.authorize.nil?
        Rails.logger.warn("[QueryConsole] Access denied: No authorization hook configured")
        render plain: "Not Found", status: :not_found
        return false
      end

      # Call the authorization hook
      unless config.authorize.call(self)
        Rails.logger.warn("[QueryConsole] Access denied by authorization hook")
        render plain: "Not Found", status: :not_found
        return false
      end
    end
  end
end
