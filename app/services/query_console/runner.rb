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
        result, rows_affected = execute_with_timeout(final_sql, is_dml)
        execution_time = ((Time.now - start_time) * 1000).round(2)

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

    def execute_with_timeout(sql, is_dml = false)
      case @config.timeout_strategy
      when :database
        execute_with_database_timeout(sql, is_dml)
      when :ruby
        execute_with_ruby_timeout(sql, is_dml)
      else
        # Auto-detect: use database timeout for PostgreSQL, Ruby timeout otherwise
        if postgresql_connection?
          execute_with_database_timeout(sql, is_dml)
        else
          execute_with_ruby_timeout(sql, is_dml)
        end
      end
    end

    # Database-level timeout (PostgreSQL only)
    # Safer: database cancels the query cleanly, no orphan processes
    def execute_with_database_timeout(sql, is_dml = false)
      conn = ActiveRecord::Base.connection
      
      unless postgresql_connection?
        Rails.logger.warn("[QueryConsole] Database timeout strategy requires PostgreSQL, falling back to Ruby timeout")
        return execute_with_ruby_timeout(sql, is_dml)
      end

      result = nil
      rows_affected = nil
      
      conn.transaction do
        # SET LOCAL scopes the timeout to this transaction only
        conn.execute("SET LOCAL statement_timeout = '#{@config.timeout_ms}'")
        result = conn.exec_query(sql)
        
        # For DML queries, capture affected rows BEFORE transaction commits
        if is_dml
          rows_affected = get_affected_rows_count_immediate(result)
        end
      end
      
      [result, rows_affected]
    rescue ActiveRecord::StatementInvalid => e
      if e.message.include?("canceling statement due to statement timeout") ||
         e.message.include?("query_canceled")
        raise Timeout::Error, "Query timeout: exceeded #{@config.timeout_ms}ms limit"
      else
        raise
      end
    end

    # Ruby-level timeout (fallback for non-PostgreSQL databases)
    # Warning: The database query continues running as an orphan process
    # even after Ruby times out. Can cause resource exhaustion.
    def execute_with_ruby_timeout(sql, is_dml = false)
      timeout_seconds = @config.timeout_ms / 1000.0
      
      result = Timeout.timeout(timeout_seconds) do
        ActiveRecord::Base.connection.exec_query(sql)
      end
      
      # For DML queries, capture affected rows immediately after execution
      rows_affected = nil
      if is_dml
        rows_affected = get_affected_rows_count_immediate(result)
      end
      
      [result, rows_affected]
    end

    def postgresql_connection?
      ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
    end

    # Get the number of rows affected by a DML query
    # MUST be called immediately after exec_query to capture accurate count
    def get_affected_rows_count_immediate(result)
      conn = ActiveRecord::Base.connection
      
      # Check if we cached it during database timeout
      if result.instance_variable_defined?(:@cached_rows_affected)
        cached = result.instance_variable_get(:@cached_rows_affected)
        return cached if cached
      end
      
      # For SQLite, use the raw connection's changes method
      # MUST be called immediately after query execution
      if conn.adapter_name.downcase.include?('sqlite')
        return conn.raw_connection.changes
      end
      
      # For PostgreSQL, MySQL, and others, check if result has rows_affected
      if result.respond_to?(:rows_affected) && result.rows_affected
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
