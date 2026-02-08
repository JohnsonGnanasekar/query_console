module QueryConsole
  class SqlLimiter
    class LimitResult
      attr_reader :sql, :truncated

      def initialize(sql:, truncated:)
        @sql = sql
        @truncated = truncated
      end

      def truncated?
        @truncated
      end
    end

    def initialize(sql, max_rows, config = QueryConsole.configuration)
      @sql = sql
      @max_rows = max_rows
      @config = config
    end

    def apply_limit
      # Skip limiting for DML queries (INSERT, UPDATE, DELETE, MERGE)
      if is_dml_query?
        return LimitResult.new(sql: @sql, truncated: false)
      end
      
      # Check if query already has a LIMIT clause
      if sql_has_limit?
        LimitResult.new(sql: @sql, truncated: false)
      else
        wrapped_sql = wrap_with_limit(@sql, @max_rows)
        LimitResult.new(sql: wrapped_sql, truncated: true)
      end
    end

    private

    attr_reader :sql, :max_rows, :config

    def is_dml_query?
      # Check if query is a DML operation (INSERT, UPDATE, DELETE, MERGE)
      @sql.strip.downcase.match?(/\A(insert|update|delete|merge)\b/)
    end

    def sql_has_limit?
      # Check for LIMIT clause (case-insensitive)
      # Match: "LIMIT", " LIMIT ", etc.
      @sql.match?(/\bLIMIT\b/i)
    end

    def wrap_with_limit(sql, limit)
      # Wrap the query in a subquery with LIMIT
      # This preserves most SQL semantics including ORDER BY, etc.
      "SELECT * FROM (#{sql}) qc_subquery LIMIT #{limit}"
    end
  end
end
