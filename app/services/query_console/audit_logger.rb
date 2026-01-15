module QueryConsole
  class AuditLogger
    def self.log_query(sql:, result:, actor: "unknown", controller: nil)
      config = QueryConsole.configuration
      
      # Resolve actor from config if controller is provided
      resolved_actor = if controller && config.current_actor.respond_to?(:call)
        config.current_actor.call(controller)
      else
        actor
      end

      log_data = {
        component: "query_console",
        actor: resolved_actor,
        sql: sql.to_s.strip,
        duration_ms: result.execution_time_ms,
        status: result.success? ? "ok" : "error"
      }

      # Add row count if available (for QueryResult)
      if result.respond_to?(:row_count_shown)
        log_data[:rows] = result.row_count_shown
      end

      if result.failure?
        log_data[:error] = result.error
        log_data[:error_class] = determine_error_class(result.error)
      end

      if result.respond_to?(:truncated) && result.truncated
        log_data[:truncated] = true
        log_data[:max_rows] = config.max_rows
      end

      Rails.logger.info(log_data.to_json)
    end

    def self.determine_error_class(error_message)
      case error_message
      when /timeout/i
        "TimeoutError"
      when /forbidden keyword/i
        "SecurityError"
      when /multiple statements/i
        "SecurityError"
      when /must start with/i
        "ValidationError"
      else
        "QueryError"
      end
    end
  end
end
