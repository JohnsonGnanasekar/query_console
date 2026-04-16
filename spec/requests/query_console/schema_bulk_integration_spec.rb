require 'rails_helper'

RSpec.describe "Schema Bulk API Integration", type: :request do
  let(:config) { QueryConsole.configuration }

  before do
    QueryConsole.reset_configuration!
    config.authorize = ->(_controller) { true }
    config.schema_explorer = true
    config.enable_autocomplete = true
    
    # Ensure test tables exist
    unless ActiveRecord::Base.connection.table_exists?('test_users')
      ActiveRecord::Base.connection.execute(<<~SQL)
        CREATE TABLE test_users (
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          email TEXT NOT NULL,
          phone TEXT,
          created_at DATETIME
        )
      SQL
    end
    
    unless ActiveRecord::Base.connection.table_exists?('test_posts')
      ActiveRecord::Base.connection.execute(<<~SQL)
        CREATE TABLE test_posts (
          id INTEGER PRIMARY KEY,
          user_id INTEGER NOT NULL,
          title TEXT NOT NULL,
          content TEXT,
          published BOOLEAN DEFAULT 0
        )
      SQL
    end
  end

  after do
    # Cleanup test tables
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS test_users")
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS test_posts")
  end

  describe "GET /query_console/schema/bulk" do
    context "with autocomplete enabled" do
      it "returns JSON array of tables with columns" do
        get "/query_console/schema/bulk"
        
        expect(response).to have_http_status(:success)
        expect(response.content_type).to match(%r{application/json})
        
        json = JSON.parse(response.body)
        expect(json).to be_an(Array)
        expect(json).not_to be_empty
        
        # Verify structure
        test_users_table = json.find { |t| t["name"] == "test_users" }
        expect(test_users_table).to be_present
        expect(test_users_table["columns"]).to include("id", "name", "email", "phone")
        expect(test_users_table).to have_key("kind")
      end

      it "includes multiple tables" do
        get "/query_console/schema/bulk"
        
        json = JSON.parse(response.body)
        table_names = json.map { |t| t["name"] }
        
        expect(table_names).to include("test_users")
        expect(table_names).to include("test_posts")
      end

      it "respects max_tables limit" do
        config.autocomplete_max_tables = 1
        
        get "/query_console/schema/bulk"
        
        json = JSON.parse(response.body)
        expect(json.length).to eq(1)
      end

      it "respects max_columns_per_table limit" do
        config.autocomplete_max_columns_per_table = 2
        
        get "/query_console/schema/bulk"
        
        json = JSON.parse(response.body)
        json.each do |table|
          expect(table["columns"].length).to be <= 2
        end
      end

      it "respects schema_table_denylist" do
        config.schema_table_denylist = ["test_posts"]
        
        get "/query_console/schema/bulk"
        
        json = JSON.parse(response.body)
        table_names = json.map { |t| t["name"] }
        
        expect(table_names).not_to include("test_posts")
        expect(table_names).to include("test_users")
      end
    end

    context "when autocomplete is disabled" do
      before do
        config.enable_autocomplete = false
      end

      it "returns 403 forbidden" do
        get "/query_console/schema/bulk"
        
        expect(response).to have_http_status(:forbidden)
        
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Autocomplete is disabled")
      end
    end

    context "when schema_explorer is disabled" do
      before do
        config.schema_explorer = false
      end

      it "returns 403 forbidden" do
        get "/query_console/schema/bulk"
        
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when not authorized" do
      before do
        config.authorize = ->(_controller) { false }
      end

      it "returns 404" do
        get "/query_console/schema/bulk"
        expect(response).to have_http_status(:not_found)
      end
    end

    context "performance" do
      it "returns response quickly" do
        start_time = Time.now
        get "/query_console/schema/bulk"
        duration = Time.now - start_time
        
        expect(response).to have_http_status(:success)
        expect(duration).to be < 1.0
      end

      it "returns compact payload" do
        get "/query_console/schema/bulk"
        
        expect(response).to have_http_status(:success)
        expect(response.body.bytesize).to be < 100_000
      end
    end

    context "edge cases" do
      it "handles empty table columns gracefully" do
        # This tests nil safety in the bulk action
        allow_any_instance_of(QueryConsole::SchemaIntrospector)
          .to receive(:table_details).and_return(nil)
        
        get "/query_console/schema/bulk"
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        json.each do |table|
          expect(table["columns"]).to be_an(Array)
        end
      end

      it "handles zero max_tables configuration" do
        # Should error on validation
        expect {
          config.autocomplete_max_tables = 0
        }.to raise_error(ArgumentError, /must be between 1 and 1000/)
      end

      it "handles very large max_tables within limits" do
        config.autocomplete_max_tables = 1000
        
        get "/query_console/schema/bulk"
        
        expect(response).to have_http_status(:success)
      end
    end
  end
end
