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
        result = execute_with_timeout(explain_sql)
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

    def execute_with_timeout(sql)
      timeout_seconds = @config.timeout_ms / 1000.0
      
      Timeout.timeout(timeout_seconds) do
        ActiveRecord::Base.connection.exec_query(sql)
      end
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
