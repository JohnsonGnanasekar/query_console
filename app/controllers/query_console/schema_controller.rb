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
  end
end
