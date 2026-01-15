require 'rails_helper'

RSpec.describe QueryConsole::ExplainController, type: :controller do
  routes { QueryConsole::Engine.routes }

  let(:config) { QueryConsole.configuration }

  before do
    QueryConsole.reset_configuration!
    config.authorize = ->(_controller) { true } # Allow access for tests
    
    # Ensure users table exists for EXPLAIN tests
    ActiveRecord::Base.connection.execute(<<~SQL) unless ActiveRecord::Base.connection.table_exists?('users')
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        name TEXT,
        email TEXT
      )
    SQL
  end

  describe "POST #create" do
    context "when not authorized" do
      before do
        config.authorize = nil # Deny by default
      end

      it "returns 404" do
        post :create, params: { sql: "SELECT * FROM users" }
        expect(response.status).to eq(404)
      end
    end

    context "when authorized" do
      context "with empty SQL" do
        it "returns error result" do
          post :create, params: { sql: "" }, format: :html
          expect(response).to be_successful
          expect(response.body).to include("Query cannot be empty")
        end
      end

      context "with invalid SQL" do
        it "returns validation error for UPDATE" do
          post :create, params: { sql: "UPDATE users SET name = 'test'" }, format: :html
          expect(response).to be_successful
          expect(response.body).to include("Query must start with one of")
        end

        it "returns validation error for DROP" do
          post :create, params: { sql: "DROP TABLE users" }, format: :html
          expect(response).to be_successful
          expect(response.body).to include("Query must start with one of")
        end
      end

      context "with valid SELECT SQL" do
        it "executes EXPLAIN and returns results" do
          post :create, params: { sql: "SELECT * FROM users" }, format: :html
          expect(response).to be_successful
          expect(response.body).to include("Query Execution Plan")
        end

        it "includes execution time" do
          post :create, params: { sql: "SELECT * FROM users" }, format: :html
          expect(response).to be_successful
          expect(response.body).to match(/Execution time:.*ms/)
        end
      end

      context "with valid WITH SQL" do
        let(:with_query) do
          <<~SQL
            WITH recent_users AS (
              SELECT * FROM users WHERE id > 10
            )
            SELECT * FROM recent_users
          SQL
        end

        it "executes EXPLAIN for CTE" do
          post :create, params: { sql: with_query }, format: :html
          expect(response).to be_successful
          expect(response.body).to include("Query Execution Plan")
        end
      end

      context "when EXPLAIN is disabled" do
        before do
          config.enable_explain = false
        end

        it "returns error message" do
          post :create, params: { sql: "SELECT * FROM users" }, format: :html
          expect(response).to be_successful
          expect(response.body).to include("EXPLAIN feature is disabled")
        end
      end
    end

    context "environment gating" do
      before do
        config.enabled_environments = ["production"]
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
      end

      it "returns 404 when not in enabled environment" do
        post :create, params: { sql: "SELECT * FROM users" }
        expect(response.status).to eq(404)
      end
    end
  end
end
