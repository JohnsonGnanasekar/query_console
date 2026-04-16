require 'rails_helper'

RSpec.describe "QueryConsole Schema Bulk API", type: :request do
  let(:config) { QueryConsole.configuration }

  before do
    QueryConsole.reset_configuration!
    config.authorize = ->(_controller) { true }
    
    # Ensure test tables exist
    ActiveRecord::Base.connection.execute(<<~SQL) unless ActiveRecord::Base.connection.table_exists?('users')
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        name TEXT,
        email TEXT,
        phone TEXT
      )
    SQL
    
    ActiveRecord::Base.connection.execute(<<~SQL) unless ActiveRecord::Base.connection.table_exists?('posts')
      CREATE TABLE posts (
        id INTEGER PRIMARY KEY,
        user_id INTEGER,
        title TEXT,
        content TEXT
      )
    SQL
  end

  describe "GET /query_console/schema/bulk" do
    context "when autocomplete is enabled" do
      before do
        config.schema_explorer = true
        config.enable_autocomplete = true
      end

      it "returns success status" do
        get "/query_console/schema/bulk"
        expect(response).to have_http_status(:success)
      end

      it "returns JSON with correct content type" do
        get "/query_console/schema/bulk"
        expect(response.content_type).to include("application/json")
      end

      it "returns array of tables with columns" do
        get "/query_console/schema/bulk"
        
        json_response = JSON.parse(response.body)
        expect(json_response).to be_an(Array)
        
        # Find users table
        users_table = json_response.find { |t| t["name"] == "users" }
        expect(users_table).to be_present
        expect(users_table["columns"]).to include("id", "name", "email", "phone")
        expect(users_table["kind"]).to eq("table")
      end

      it "includes all expected tables" do
        get "/query_console/schema/bulk"
        
        json_response = JSON.parse(response.body)
        table_names = json_response.map { |t| t["name"] }
        
        expect(table_names).to include("users", "posts")
      end

      context "with max_tables limit" do
        before do
          config.autocomplete_max_tables = 1
        end

        it "limits number of tables returned" do
          get "/query_console/schema/bulk"
          
          json_response = JSON.parse(response.body)
          expect(json_response.length).to be <= 1
        end
      end

      context "with max_columns_per_table limit" do
        before do
          config.autocomplete_max_columns_per_table = 2
        end

        it "limits number of columns per table" do
          get "/query_console/schema/bulk"
          
          json_response = JSON.parse(response.body)
          json_response.each do |table|
            expect(table["columns"].length).to be <= 2
          end
        end
      end

      context "with table denylist" do
        before do
          config.schema_table_denylist = ["posts"]
        end

        it "excludes denylisted tables" do
          get "/query_console/schema/bulk"
          
          json_response = JSON.parse(response.body)
          table_names = json_response.map { |t| t["name"] }
          
          expect(table_names).not_to include("posts")
          expect(table_names).to include("users")
        end
      end
    end

    context "when autocomplete is disabled" do
      before do
        config.enable_autocomplete = false
      end

      it "returns forbidden status" do
        get "/query_console/schema/bulk"
        
        expect(response).to have_http_status(:forbidden)
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to eq("Autocomplete is disabled")
      end
    end

    context "when schema_explorer is disabled" do
      before do
        config.schema_explorer = false
        config.enable_autocomplete = true
      end

      it "returns forbidden status" do
        get "/query_console/schema/bulk"
        
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when not authorized" do
      before do
        config.authorize = nil
      end

      it "returns 404" do
        get "/query_console/schema/bulk"
        expect(response).to have_http_status(:not_found)
      end
    end

    context "performance considerations" do
      it "completes within reasonable time" do
        config.schema_explorer = true
        config.enable_autocomplete = true
        
        start_time = Time.now
        get "/query_console/schema/bulk"
        duration = Time.now - start_time
        
        expect(response).to have_http_status(:success)
        expect(duration).to be < 1.0 # Should complete within 1 second
      end

      it "returns reasonable payload size" do
        config.schema_explorer = true
        config.enable_autocomplete = true
        
        get "/query_console/schema/bulk"
        
        payload_size = response.body.bytesize
        expect(payload_size).to be < 1_000_000 # Less than 1MB
      end
    end
  end
end
