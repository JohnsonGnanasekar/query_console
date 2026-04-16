require 'timeout'

module QueryConsole
  class ExplainRunner
    class ExplainResult
      attr_reader :plan_text, :execution_time_ms, :error

      def initialize(plan_text: nil, execution_time_ms: 0, error: nil)
        @plan_text = plan_text
        @execution_time_ms = execution_time_ms
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
      return ExplainResult.new(error: "EXPLAIN feature is disabled") unless @config.enable_explain

      start_time = Time.now

      # Step 1: Validate SQL (same as regular runner)
      validator = SqlValidator.new(@sql, @config)
      validation_result = validator.validate

      if validation_result.invalid?
        return ExplainResult.new(error: validation_result.error)
      end

      sanitized_sql = validation_result.sanitized_sql

      # Step 2: Build EXPLAIN query based on adapter
      explain_sql = build_explain_query(sanitized_sql)

      # Step 3: Execute with timeout
      begin
        result, _ = execute_with_timeout(explain_sql, false)
        execution_time = ((Time.now - start_time) * 1000).round(2)

        # Format the result as plain text
        plan_text = format_explain_output(result)

        ExplainResult.new(
          plan_text: plan_text,
          execution_time_ms: execution_time
        )
      rescue Timeout::Error
        ExplainResult.new(
          error: "EXPLAIN timeout: exceeded #{@config.timeout_ms}ms limit"
        )
      rescue StandardError => e
        ExplainResult.new(
          error: "EXPLAIN error: #{e.message}"
        )
      end
    end

    private

    attr_reader :sql, :config

    def build_explain_query(sql)
      adapter_name = ActiveRecord::Base.connection.adapter_name

      case adapter_name
      when "PostgreSQL"
        if @config.enable_explain_analyze
          "EXPLAIN (ANALYZE, FORMAT TEXT) #{sql}"
        else
          "EXPLAIN (FORMAT TEXT) #{sql}"
        end
      when "Mysql2", "Trilogy"
        if @config.enable_explain_analyze
          "EXPLAIN ANALYZE #{sql}"
        else
          "EXPLAIN #{sql}"
        end
      when "SQLite"
        # SQLite doesn't support ANALYZE in EXPLAIN
        "EXPLAIN QUERY PLAN #{sql}"
      else
        # Fallback for other adapters
        "EXPLAIN #{sql}"
      end
    end

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

      result = conn.transaction do
        # SET LOCAL scopes the timeout to this transaction only
        conn.execute("SET LOCAL statement_timeout = '#{@config.timeout_ms}'")
        conn.exec_query(sql)
      end
      
      # EXPLAIN queries never have rows_affected
      [result, nil]
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
      
      # EXPLAIN queries never have rows_affected
      [result, nil]
    end

    def postgresql_connection?
      ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
    end

    def format_explain_output(result)
      # For SQLite, the result has columns like: id, parent, notused, detail
      # For Postgres, it's usually a single "QUERY PLAN" column
      # For MySQL, it varies by version

      adapter_name = ActiveRecord::Base.connection.adapter_name

      case adapter_name
      when "SQLite"
        # SQLite EXPLAIN QUERY PLAN format
        lines = result.rows.map do |row|
          # row is [id, parent, notused, detail]
          detail = row[3] || row.last
          detail.to_s
        end
        lines.join("\n")
      when "PostgreSQL"
        # Postgres returns single column with plan text
        result.rows.map { |row| row[0].to_s }.join("\n")
      when "Mysql2", "Trilogy"
        # MySQL returns multiple columns, format as table
        header = result.columns.join(" | ")
        separator = "-" * header.length
        rows = result.rows.map { |row| row.map(&:to_s).join(" | ") }
        ([header, separator] + rows).join("\n")
      else
        # Generic fallback
        result.rows.map { |row| row.join(" | ") }.join("\n")
      end
    end
  end
end
