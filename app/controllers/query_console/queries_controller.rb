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

      # Execute the query
      runner = Runner.new(sql)
      @result = runner.execute

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
            locals: { result: @result }
          )
        end
        format.html { render :_results, layout: false }
      end
    end
  end
end
