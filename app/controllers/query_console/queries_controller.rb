module QueryConsole
  class QueriesController < ApplicationController
    def new
      # Render the main query editor page
    end

    def run
      sql = params[:sql]

      if sql.blank?
        @result = Runner::QueryResult.new(error: "Query cannot be empty")
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.replace("query-results", partial: "results", locals: { result: @result }) }
          format.html { render :_results, layout: false }
        end
        return
      end

      # SECURITY FIX: Server-side DML confirmation check
      # Validate DML confirmation before execution
      config = QueryConsole.configuration
      if config.enable_dml
        # Quick check if SQL contains DML keywords
        normalized_sql = sql.strip.downcase
        if normalized_sql.match?(/\A(insert|update|delete|merge)\b/)
          # This is a DML query - require confirmation
          unless params[:dml_confirmed] == 'true'
            @result = Runner::QueryResult.new(
              error: "DML query execution requires user confirmation. Please confirm the operation to proceed."
            )
            respond_to do |format|
              format.turbo_stream { render turbo_stream: turbo_stream.replace("query-results", partial: "results", locals: { result: @result, is_dml: false }) }
              format.html { render :_results, layout: false }
            end
            return
          end
        end
      end

      # Execute the query
      runner = Runner.new(sql)
      @result = runner.execute
      @is_dml = @result.dml?

      # Log the query execution
      AuditLogger.log_query(
        sql: sql,
        result: @result,
        controller: self
      )

      # Respond with Turbo Stream or HTML
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "query-results",
            partial: "results",
            locals: { result: @result, is_dml: @is_dml }
          )
        end
        format.html { render :_results, layout: false }
      end
    end
  end
end
