module QueryConsole
  class SchemaIntrospector
    def initialize(config = QueryConsole.configuration)
      @config = config
    end

    def tables
      return [] unless @config.schema_explorer

      Rails.cache.fetch(cache_key_tables, expires_in: @config.schema_cache_seconds) do
        fetch_tables
      end
    end

    def table_details(table_name)
      return nil unless @config.schema_explorer
      return nil if table_denied?(table_name)

      Rails.cache.fetch(cache_key_table(table_name), expires_in: @config.schema_cache_seconds) do
        fetch_table_details(table_name)
      end
    end

    private

    attr_reader :config

    def fetch_tables
      adapter_name = ActiveRecord::Base.connection.adapter_name
      
      raw_tables = case adapter_name
      when "PostgreSQL"
        fetch_postgresql_tables
      when "Mysql2", "Trilogy"
        fetch_mysql_tables
      when "SQLite"
        fetch_sqlite_tables
      else
        # Fallback for other adapters
        ActiveRecord::Base.connection.tables.map { |name| { name: name, kind: "table" } }
      end

      # Apply filtering
      filter_tables(raw_tables)
    end

    def fetch_postgresql_tables
      sql = <<~SQL
        SELECT 
          table_name as name,
          table_type as kind
        FROM information_schema.tables
        WHERE table_schema = 'public'
        ORDER BY table_name
      SQL

      result = ActiveRecord::Base.connection.exec_query(sql)
      result.rows.map do |row|
        {
          name: row[0],
          kind: row[1].downcase.include?("view") ? "view" : "table"
        }
      end
    end

    def fetch_mysql_tables
      sql = <<~SQL
        SELECT 
          table_name as name,
          table_type as kind
        FROM information_schema.tables
        WHERE table_schema = DATABASE()
        ORDER BY table_name
      SQL

      result = ActiveRecord::Base.connection.exec_query(sql)
      result.rows.map do |row|
        {
          name: row[0],
          kind: row[1].downcase.include?("view") ? "view" : "table"
        }
      end
    end

    def fetch_sqlite_tables
      sql = <<~SQL
        SELECT name, type
        FROM sqlite_master
        WHERE type IN ('table', 'view')
        AND name NOT LIKE 'sqlite_%'
        ORDER BY name
      SQL

      result = ActiveRecord::Base.connection.exec_query(sql)
      result.rows.map do |row|
        {
          name: row[0],
          kind: row[1]
        }
      end
    end

    def fetch_table_details(table_name)
      adapter_name = ActiveRecord::Base.connection.adapter_name
      
      columns = case adapter_name
      when "PostgreSQL"
        fetch_postgresql_columns(table_name)
      when "Mysql2", "Trilogy"
        fetch_mysql_columns(table_name)
      when "SQLite"
        fetch_sqlite_columns(table_name)
      else
        # Fallback using ActiveRecord
        fetch_activerecord_columns(table_name)
      end

      {
        name: table_name,
        columns: columns
      }
    end

    def fetch_postgresql_columns(table_name)
      sql = <<~SQL
        SELECT 
          column_name,
          data_type,
          is_nullable,
          column_default
        FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = '#{sanitize_table_name(table_name)}'
        ORDER BY ordinal_position
      SQL

      result = ActiveRecord::Base.connection.exec_query(sql)
      result.rows.map do |row|
        {
          name: row[0],
          db_type: row[1],
          nullable: row[2] == "YES",
          default: row[3]
        }
      end
    end

    def fetch_mysql_columns(table_name)
      sql = <<~SQL
        SELECT 
          column_name,
          data_type,
          is_nullable,
          column_default
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
        AND table_name = '#{sanitize_table_name(table_name)}'
        ORDER BY ordinal_position
      SQL

      result = ActiveRecord::Base.connection.exec_query(sql)
      result.rows.map do |row|
        {
          name: row[0],
          db_type: row[1],
          nullable: row[2] == "YES",
          default: row[3]
        }
      end
    end

    def fetch_sqlite_columns(table_name)
      sql = "PRAGMA table_info(#{sanitize_table_name(table_name)})"
      result = ActiveRecord::Base.connection.exec_query(sql)
      
      result.rows.map do |row|
        # SQLite PRAGMA returns: cid, name, type, notnull, dflt_value, pk
        {
          name: row[1],
          db_type: row[2],
          nullable: row[3] == 0,
          default: row[4]
        }
      end
    end

    def fetch_activerecord_columns(table_name)
      columns = ActiveRecord::Base.connection.columns(table_name)
      columns.map do |col|
        {
          name: col.name,
          db_type: col.sql_type,
          nullable: col.null,
          default: col.default
        }
      end
    rescue StandardError
      []
    end

    def filter_tables(tables)
      tables.select do |table|
        # Check denylist
        next false if @config.schema_table_denylist.include?(table[:name])
        
        # Check allowlist (if present)
        if @config.schema_allowlist.any?
          next @config.schema_allowlist.include?(table[:name])
        end
        
        true
      end
    end

    def table_denied?(table_name)
      # Check denylist
      return true if @config.schema_table_denylist.include?(table_name)
      
      # Check allowlist (if present)
      if @config.schema_allowlist.any?
        return !@config.schema_allowlist.include?(table_name)
      end
      
      false
    end

    def sanitize_table_name(name)
      # Basic SQL injection protection - only allow alphanumeric, underscore
      name.to_s.gsub(/[^a-zA-Z0-9_]/, '')
    end

    def cache_key_tables
      "query_console/schema/tables/#{adapter_identifier}"
    end

    def cache_key_table(table_name)
      "query_console/schema/table/#{adapter_identifier}/#{table_name}"
    end

    def adapter_identifier
      ActiveRecord::Base.connection.adapter_name.downcase
    end
  end
end
