require "rails_helper"

module QueryConsole
  RSpec.describe SchemaController, type: :controller do
    routes { QueryConsole::Engine.routes }

    let(:config) { QueryConsole.configuration }

    before do
      QueryConsole.reset_configuration!
      config.authorize = ->(_controller) { true } # Allow access for tests
    end

    describe "GET #bulk" do
      context "when autocomplete is enabled" do
        before do
          config.schema_explorer = true
          config.enable_autocomplete = true
          config.autocomplete_max_tables = 5
          config.autocomplete_max_columns_per_table = 10
        end

        it "returns tables with columns in JSON format" do
          get :bulk, format: :json
          
          expect(response).to have_http_status(:success)
          expect(response.content_type).to include("application/json")
          
          json_response = JSON.parse(response.body)
          expect(json_response).to be_an(Array)
          
          # Verify structure
          unless json_response.empty?
            first_table = json_response.first
            expect(first_table).to have_key("name")
            expect(first_table).to have_key("columns")
            expect(first_table["columns"]).to be_an(Array)
          end
        end

        it "respects max_tables configuration" do
          config.autocomplete_max_tables = 2
          
          get :bulk, format: :json
          
          json_response = JSON.parse(response.body)
          expect(json_response.length).to be <= 2
        end

        it "respects max_columns_per_table configuration" do
          config.autocomplete_max_columns_per_table = 3
          
          get :bulk, format: :json
          
          json_response = JSON.parse(response.body)
          json_response.each do |table|
            expect(table["columns"].length).to be <= 3
          end
        end
      end

      context "when autocomplete is disabled" do
        before do
          config.enable_autocomplete = false
        end

        it "returns forbidden status" do
          get :bulk, format: :json
          
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

        it "returns forbidden status because autocomplete_enabled requires schema_explorer" do
          get :bulk, format: :json
          
          expect(response).to have_http_status(:forbidden)
        end
      end
    end
  end
end
