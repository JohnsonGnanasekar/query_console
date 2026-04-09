module QueryConsole
  class SqlValidator
    class ValidationResult
      attr_reader :valid, :error, :sanitized_sql, :is_dml

      def initialize(valid:, sanitized_sql: nil, error: nil, is_dml: false)
        @valid = valid
        @sanitized_sql = sanitized_sql
        @error = error
        @is_dml = is_dml
      end

      def valid?
        @valid
      end

      def invalid?
        !@valid
      end

      def dml?
        @is_dml
      end
    end

    def initialize(sql, config = QueryConsole.configuration)
      @sql = sql
      @config = config
    end

    def validate
      return ValidationResult.new(valid: false, error: "Query cannot be empty") if sql.nil? || sql.strip.empty?

      sanitized = sql.strip
      
      # Remove a single trailing semicolon if present
      sanitized = sanitized.sub(/;\s*\z/, '')

      # Check for multiple statements (any remaining semicolons)
      if sanitized.include?(';')
        return ValidationResult.new(
          valid: false,
          error: "Multiple statements are not allowed. Only single SELECT or WITH queries are permitted."
        )
      end

      # Check if query starts with allowed keywords
      normalized_start = sanitized.downcase
      
      # Define DML-specific keywords that are conditionally allowed
      dml_keywords = %w[insert update delete merge]
      
      # Expand allowed_starts_with if DML is enabled
      effective_allowed = if @config.enable_dml
        @config.allowed_starts_with + dml_keywords
      else
        @config.allowed_starts_with
      end
      
      unless effective_allowed.any? { |keyword| normalized_start.start_with?(keyword) }
        return ValidationResult.new(
          valid: false,
          error: "Query must start with one of: #{effective_allowed.join(', ').upcase}"
        )
      end

      # Check for forbidden keywords
      normalized_query = sanitized.downcase
      
      # SECURITY FIX: When DML is enabled, we still need to prevent DML in subqueries
      # Only allow DML at the top level (start of query)
      if @config.enable_dml
        # Check if this is a top-level DML query
        is_top_level_dml = normalized_start.match?(/\A(insert|update|delete|merge)\b/)
        
        # If DML keywords appear anywhere else (subqueries, CTEs), block them
        if !is_top_level_dml && normalized_query.match?(/\b(insert|update|delete|merge)\b/)
          return ValidationResult.new(
            valid: false,
            error: "DML keywords (INSERT, UPDATE, DELETE, MERGE) are not allowed in subqueries or WITH clauses"
          )
        end
        
        # Filter forbidden keywords - only remove DML from forbidden list for top-level queries
        effective_forbidden = @config.forbidden_keywords.reject { |kw| dml_keywords.include?(kw) || kw == 'replace' || kw == 'into' }
      else
        effective_forbidden = @config.forbidden_keywords
      end
      
      forbidden = effective_forbidden.find do |keyword|
        # Match whole words to avoid false positives (e.g., "updates" table name)
        normalized_query.match?(/\b#{Regexp.escape(keyword.downcase)}\b/)
      end

      if forbidden
        return ValidationResult.new(
          valid: false,
          error: "Forbidden keyword detected: #{forbidden.upcase}. Only read-only SELECT queries are allowed."
        )
      end

      # Detect if this is a DML query (top-level only)
      is_dml_query = sanitized.downcase.match?(/\A(insert|update|delete|merge)\b/)

      ValidationResult.new(valid: true, sanitized_sql: sanitized, is_dml: is_dml_query)
    end

    private

    attr_reader :sql, :config
  end
end
