module QueryConsole
  class QueriesController < ApplicationController
    def new
      # Render the main query editor page
    end

    def run
      sql = params[:sql]

      if sql.blank?
        @result = Runner::QueryResult.new(error: "Query cannot be empty")
        render :_results, layout: false
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

      # Render the results partial
      render :_results, layout: false
    end
  end
end
