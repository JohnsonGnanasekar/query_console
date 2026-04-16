module QueryConsole
  class SchemaController < ApplicationController
    def tables
      unless QueryConsole.configuration.schema_explorer
        render json: { error: "Schema explorer is disabled" }, status: :forbidden
        return
      end

      introspector = SchemaIntrospector.new
      @tables = introspector.tables

      render json: @tables
    end

    def show
      unless QueryConsole.configuration.schema_explorer
        render json: { error: "Schema explorer is disabled" }, status: :forbidden
        return
      end

      introspector = SchemaIntrospector.new
      @table = introspector.table_details(params[:name])

      if @table.nil?
        render json: { error: "Table not found or access denied" }, status: :not_found
        return
      end

      render json: @table
    end

    # Bulk endpoint to fetch all tables with columns in a single request
    # Prevents N+1 problem for autocomplete
    def bulk
      unless QueryConsole.configuration.autocomplete_enabled
        render json: { error: "Autocomplete is disabled" }, status: :forbidden
        return
      end

      config = QueryConsole.configuration
      introspector = SchemaIntrospector.new
      
      # Apply autocomplete limits
      max_tables = config.autocomplete_max_tables
      max_columns = config.autocomplete_max_columns_per_table
      
      tables = introspector.tables.first(max_tables)
      
      # Fetch all table details in one pass (server-side batching)
      tables_with_columns = tables.map do |table|
        details = introspector.table_details(table[:name])
        columns = details ? details[:columns].first(max_columns).map { |c| c[:name] } : []
        
        {
          name: table[:name],
          kind: table[:kind],
          columns: columns
        }
      end
      
      render json: tables_with_columns
    end
  end
end
