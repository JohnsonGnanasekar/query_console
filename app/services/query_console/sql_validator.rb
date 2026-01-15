module QueryConsole
  class SqlValidator
    class ValidationResult
      attr_reader :valid, :error, :sanitized_sql

      def initialize(valid:, sanitized_sql: nil, error: nil)
        @valid = valid
        @sanitized_sql = sanitized_sql
        @error = error
      end

      def valid?
        @valid
      end

      def invalid?
        !@valid
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
      unless @config.allowed_starts_with.any? { |keyword| normalized_start.start_with?(keyword) }
        return ValidationResult.new(
          valid: false,
          error: "Query must start with one of: #{@config.allowed_starts_with.join(', ').upcase}"
        )
      end

      # Check for forbidden keywords
      normalized_query = sanitized.downcase
      forbidden = @config.forbidden_keywords.find do |keyword|
        # Match whole words to avoid false positives (e.g., "updates" table name)
        normalized_query.match?(/\b#{Regexp.escape(keyword.downcase)}\b/)
      end

      if forbidden
        return ValidationResult.new(
          valid: false,
          error: "Forbidden keyword detected: #{forbidden.upcase}. Only read-only SELECT queries are allowed."
        )
      end

      ValidationResult.new(valid: true, sanitized_sql: sanitized)
    end

    private

    attr_reader :sql, :config
  end
end
