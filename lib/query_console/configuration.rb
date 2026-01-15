module QueryConsole
  class Configuration
    attr_accessor :enabled_environments,
                  :max_rows,
                  :timeout_ms,
                  :authorize,
                  :current_actor,
                  :forbidden_keywords,
                  :allowed_starts_with

    def initialize
      @enabled_environments = ["development"]
      @max_rows = 500
      @timeout_ms = 3000
      @authorize = nil # nil means deny by default
      @current_actor = -> (_controller) { "unknown" }
      @forbidden_keywords = %w[
        update delete insert drop alter create grant revoke truncate
        execute exec sp_executesql xp_ sp_ merge replace into
        shutdown backup restore transaction commit rollback
      ]
      @allowed_starts_with = %w[select with]
    end
  end

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
