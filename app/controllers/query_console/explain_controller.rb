module QueryConsole
  class ExplainController < ApplicationController
    skip_forgery_protection only: [:create] # Allow Turbo Frame POST requests

    def create
      sql = params[:sql]

      if sql.blank?
        @result = ExplainRunner::ExplainResult.new(error: "Query cannot be empty")
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              "explain-results",
              partial: "explain/results",
              locals: { result: @result }
            )
          end
          format.html { render "explain/_results", layout: false, locals: { result: @result } }
        end
        return
      end

      # Execute the EXPLAIN
      runner = ExplainRunner.new(sql)
      @result = runner.execute

      # Log the EXPLAIN execution
      AuditLogger.log_query(
        sql: "EXPLAIN: #{sql}",
        result: @result,
        controller: self
      )

      # Respond with Turbo Stream or HTML
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "explain-results",
            partial: "query_console/explain/results",
            locals: { result: @result }
          )
        end
        format.html { render "query_console/explain/_results", layout: false, locals: { result: @result } }
      end
    end
  end
end
