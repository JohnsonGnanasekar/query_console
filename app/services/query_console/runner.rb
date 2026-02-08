require 'timeout'

module QueryConsole
  class Runner
    class QueryResult
      attr_reader :columns, :rows, :execution_time_ms, :row_count_shown, :truncated, :error, :is_dml, :rows_affected

      def initialize(columns: [], rows: [], execution_time_ms: 0, row_count_shown: 0, truncated: false, error: nil, is_dml: false, rows_affected: nil)
        @columns = columns
        @rows = rows
        @execution_time_ms = execution_time_ms
        @row_count_shown = row_count_shown
        @truncated = truncated
        @error = error
        @is_dml = is_dml
        @rows_affected = rows_affected
      end

      def success?
        @error.nil?
      end

      def failure?
        !success?
      end

      def truncated?
        @truncated
      end

      def dml?
        @is_dml
      end
    end

    def initialize(sql, config = QueryConsole.configuration)
      @sql = sql
      @config = config
    end

    def execute
      start_time = Time.now

      # Step 1: Validate SQL
      validator = SqlValidator.new(@sql, @config)
      validation_result = validator.validate

      if validation_result.invalid?
        return QueryResult.new(error: validation_result.error)
      end

      sanitized_sql = validation_result.sanitized_sql
      is_dml = validation_result.dml?

      # Step 2: Apply row limit
      limiter = SqlLimiter.new(sanitized_sql, @config.max_rows, @config)
      limit_result = limiter.apply_limit
      final_sql = limit_result.sql
      truncated = limit_result.truncated?

      # Step 3: Execute query with timeout
      begin
        result = execute_with_timeout(final_sql)
        execution_time = ((Time.now - start_time) * 1000).round(2)

        # For DML queries, capture the number of affected rows
        rows_affected = nil
        if is_dml
          rows_affected = get_affected_rows_count(result)
        end

        QueryResult.new(
          columns: result.columns,
          rows: result.rows,
          execution_time_ms: execution_time,
          row_count_shown: result.rows.length,
          truncated: truncated,
          is_dml: is_dml,
          rows_affected: rows_affected
        )
      rescue Timeout::Error
        QueryResult.new(
          error: "Query timeout: exceeded #{@config.timeout_ms}ms limit"
        )
      rescue StandardError => e
        QueryResult.new(
          error: "Query error: #{e.message}"
        )
      end
    end

    private

    attr_reader :sql, :config

    def execute_with_timeout(sql)
      timeout_seconds = @config.timeout_ms / 1000.0
      
      Timeout.timeout(timeout_seconds) do
        ActiveRecord::Base.connection.exec_query(sql)
      end
    end

    # Get the number of rows affected by a DML query
    # This is database-specific, so we try different approaches
    def get_affected_rows_count(result)
      conn = ActiveRecord::Base.connection
      
      # For SQLite, use the raw connection's changes method
      if conn.adapter_name.downcase.include?('sqlite')
        return conn.raw_connection.changes
      end
      
      # For PostgreSQL, MySQL, and others, check if result has rows_affected
      # Note: exec_query doesn't always provide this, but we can try
      if result.respond_to?(:rows_affected)
        return result.rows_affected
      end
      
      # Fallback: try to get it from the connection's last result
      begin
        if conn.respond_to?(:raw_connection)
          raw_conn = conn.raw_connection
          
          # PostgreSQL
          if raw_conn.respond_to?(:cmd_tuples)
            return raw_conn.cmd_tuples
          end
          
          # MySQL
          if raw_conn.respond_to?(:affected_rows)
            return raw_conn.affected_rows
          end
        end
      rescue
        # If we can't determine affected rows, return nil
      end
      
      nil
    end
  end
end
