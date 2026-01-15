require 'timeout'

module QueryConsole
  class Runner
    class QueryResult
      attr_reader :columns, :rows, :execution_time_ms, :row_count_shown, :truncated, :error

      def initialize(columns: [], rows: [], execution_time_ms: 0, row_count_shown: 0, truncated: false, error: nil)
        @columns = columns
        @rows = rows
        @execution_time_ms = execution_time_ms
        @row_count_shown = row_count_shown
        @truncated = truncated
        @error = error
      end

      def success?
        @error.nil?
      end

      def failure?
        !success?
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

      # Step 2: Apply row limit
      limiter = SqlLimiter.new(sanitized_sql, @config.max_rows, @config)
      limit_result = limiter.apply_limit
      final_sql = limit_result.sql
      truncated = limit_result.truncated?

      # Step 3: Execute query with timeout
      begin
        result = execute_with_timeout(final_sql)
        execution_time = ((Time.now - start_time) * 1000).round(2)

        QueryResult.new(
          columns: result.columns,
          rows: result.rows,
          execution_time_ms: execution_time,
          row_count_shown: result.rows.length,
          truncated: truncated
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
  end
end
