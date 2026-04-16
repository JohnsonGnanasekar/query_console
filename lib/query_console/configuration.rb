module QueryConsole
  class Configuration
    attr_accessor :enabled_environments,
                  :max_rows,
                  :timeout_ms,
                  :timeout_strategy,
                  :authorize,
                  :current_actor,
                  :forbidden_keywords,
                  :allowed_starts_with,
                  :enable_explain,
                  :enable_explain_analyze,
                  :enable_dml,
                  :schema_explorer,
                  :schema_cache_seconds,
                  :schema_table_denylist,
                  :schema_allowlist,
                  :enable_syntax_highlighting,
                  :enable_autocomplete,
                  :autocomplete_max_tables,
                  :autocomplete_max_columns_per_table,
                  :autocomplete_cache_ttl_seconds

    def initialize
      @enabled_environments = ["development"]
      @max_rows = 500
      @timeout_ms = 3000
      @timeout_strategy = :database # :database (safer, PostgreSQL only) or :ruby (fallback, but can leave orphan queries)
      @authorize = nil # nil means deny by default
      @current_actor = -> (_controller) { "unknown" }
      @forbidden_keywords = %w[
        update delete insert drop alter create grant revoke truncate
        execute exec sp_executesql xp_ sp_ merge replace into
        shutdown backup restore transaction commit rollback
      ]
      @allowed_starts_with = %w[select with]
      
      # v0.2.0 additions
      @enable_explain = true
      @enable_explain_analyze = false # ANALYZE can be expensive, disabled by default
      @enable_dml = false # DML queries disabled by default for safety
      @schema_explorer = true
      @schema_cache_seconds = 60
      @schema_table_denylist = ["schema_migrations", "ar_internal_metadata"]
      @schema_allowlist = [] # empty means all tables allowed (except denylist)
      @enable_syntax_highlighting = true
      @enable_autocomplete = true
      @autocomplete_max_tables = 100
      @autocomplete_max_columns_per_table = 100
      @autocomplete_cache_ttl_seconds = 300 # 5 minutes
    end

    # Validation: Autocomplete requires schema_explorer to be enabled
    def autocomplete_enabled
      enable_autocomplete && schema_explorer
    end

    # Setter with validation for autocomplete_max_tables
    def autocomplete_max_tables=(value)
      raise ArgumentError, "autocomplete_max_tables must be between 1 and 1000" unless value.is_a?(Integer) && (1..1000).include?(value)
      @autocomplete_max_tables = value
    end

    # Setter with validation for autocomplete_max_columns_per_table
    def autocomplete_max_columns_per_table=(value)
      raise ArgumentError, "autocomplete_max_columns_per_table must be between 1 and 500" unless value.is_a?(Integer) && (1..500).include?(value)
      @autocomplete_max_columns_per_table = value
    end

    # Setter with validation for autocomplete_cache_ttl_seconds
    def autocomplete_cache_ttl_seconds=(value)
      raise ArgumentError, "autocomplete_cache_ttl_seconds must be positive" unless value.is_a?(Integer) && value > 0
      @autocomplete_cache_ttl_seconds = value
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
