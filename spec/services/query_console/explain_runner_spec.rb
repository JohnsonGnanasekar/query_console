require 'rails_helper'

RSpec.describe QueryConsole::ExplainRunner do
  let(:config) { QueryConsole.configuration }
  let(:valid_sql) { "SELECT * FROM users" }
  
  before do
    QueryConsole.reset_configuration!
  end

  describe "#execute" do
    context "when EXPLAIN is disabled" do
      before do
        config.enable_explain = false
      end

      it "returns an error" do
        runner = described_class.new(valid_sql)
        result = runner.execute
        
        expect(result.failure?).to be true
        expect(result.error).to eq("EXPLAIN feature is disabled")
      end
    end

    context "when EXPLAIN is enabled" do
      before do
        config.enable_explain = true
      end

      context "with empty SQL" do
        it "returns a validation error" do
          runner = described_class.new("")
          result = runner.execute
          
          expect(result.failure?).to be true
          expect(result.error).to eq("Query cannot be empty")
        end
      end

      context "with invalid SQL" do
        it "blocks UPDATE statements" do
          runner = described_class.new("UPDATE users SET name = 'test'")
          result = runner.execute
          
          expect(result.failure?).to be true
          expect(result.error).to include("Query must start with one of")
        end

        it "blocks DROP statements" do
          runner = described_class.new("DROP TABLE users")
          result = runner.execute
          
          expect(result.failure?).to be true
          expect(result.error).to include("Query must start with one of")
        end
      end

      context "with valid SELECT query" do
        before do
          # Ensure users table exists for EXPLAIN tests
          ActiveRecord::Base.connection.execute(<<~SQL) unless ActiveRecord::Base.connection.table_exists?('users')
            CREATE TABLE users (
              id INTEGER PRIMARY KEY,
              name TEXT,
              email TEXT
            )
          SQL
        end

        it "executes EXPLAIN and returns plan text" do
          runner = described_class.new(valid_sql)
          result = runner.execute
          
          expect(result.success?).to be true
          expect(result.plan_text).to be_present
          expect(result.execution_time_ms).to be >= 0
        end

        it "formats SQLite explain output" do
          # SQLite is used in test environment
          runner = described_class.new(valid_sql)
          result = runner.execute
          
          expect(result.plan_text).to be_a(String)
          expect(result.plan_text.length).to be > 0
        end
      end

      context "with valid WITH query" do
        before do
          # Ensure users table exists for WITH query tests
          ActiveRecord::Base.connection.execute(<<~SQL) unless ActiveRecord::Base.connection.table_exists?('users')
            CREATE TABLE users (
              id INTEGER PRIMARY KEY,
              name TEXT,
              email TEXT
            )
          SQL
        end

        let(:with_query) do
          <<~SQL
            WITH recent_users AS (
              SELECT * FROM users WHERE id > 10
            )
            SELECT * FROM recent_users
          SQL
        end

        it "executes EXPLAIN for CTE queries" do
          runner = described_class.new(with_query)
          result = runner.execute
          
          expect(result.success?).to be true
          expect(result.plan_text).to be_present
        end
      end

      context "when query timeout is exceeded" do
        before do
          # Ensure users table exists
          ActiveRecord::Base.connection.execute(<<~SQL) unless ActiveRecord::Base.connection.table_exists?('users')
            CREATE TABLE users (
              id INTEGER PRIMARY KEY,
              name TEXT,
              email TEXT
            )
          SQL
          
          config.timeout_ms = 1 # 1ms timeout
          allow_any_instance_of(described_class).to receive(:execute_with_timeout)
            .and_raise(Timeout::Error)
        end

        it "returns a timeout error" do
          runner = described_class.new(valid_sql)
          result = runner.execute
          
          expect(result.failure?).to be true
          expect(result.error).to include("EXPLAIN timeout")
        end
      end
    end

    describe "adapter detection" do
      before do
        # Ensure users table exists
        ActiveRecord::Base.connection.execute(<<~SQL) unless ActiveRecord::Base.connection.table_exists?('users')
          CREATE TABLE users (
            id INTEGER PRIMARY KEY,
            name TEXT,
            email TEXT
          )
        SQL
      end

      it "detects SQLite adapter" do
        runner = described_class.new(valid_sql)
        adapter_name = ActiveRecord::Base.connection.adapter_name
        
        expect(adapter_name).to eq("SQLite")
      end

      it "builds correct EXPLAIN query for SQLite" do
        runner = described_class.new(valid_sql)
        explain_sql = runner.send(:build_explain_query, valid_sql)
        
        expect(explain_sql).to eq("EXPLAIN QUERY PLAN #{valid_sql}")
      end

      context "with ANALYZE enabled" do
        before do
          config.enable_explain_analyze = true
        end

        it "SQLite ignores ANALYZE flag" do
          runner = described_class.new(valid_sql)
          explain_sql = runner.send(:build_explain_query, valid_sql)
          
          # SQLite doesn't support ANALYZE in EXPLAIN
          expect(explain_sql).to eq("EXPLAIN QUERY PLAN #{valid_sql}")
        end
      end
    end

    describe "#build_explain_query" do
      let(:runner) { described_class.new(valid_sql) }

      context "for PostgreSQL" do
        before do
          allow(ActiveRecord::Base.connection).to receive(:adapter_name).and_return("PostgreSQL")
        end

        it "builds FORMAT TEXT query without ANALYZE" do
          config.enable_explain_analyze = false
          sql = runner.send(:build_explain_query, valid_sql)
          
          expect(sql).to eq("EXPLAIN (FORMAT TEXT) #{valid_sql}")
        end

        it "builds FORMAT TEXT ANALYZE query when enabled" do
          config.enable_explain_analyze = true
          sql = runner.send(:build_explain_query, valid_sql)
          
          expect(sql).to eq("EXPLAIN (ANALYZE, FORMAT TEXT) #{valid_sql}")
        end
      end

      context "for MySQL" do
        before do
          allow(ActiveRecord::Base.connection).to receive(:adapter_name).and_return("Mysql2")
        end

        it "builds simple EXPLAIN query without ANALYZE" do
          config.enable_explain_analyze = false
          sql = runner.send(:build_explain_query, valid_sql)
          
          expect(sql).to eq("EXPLAIN #{valid_sql}")
        end

        it "builds EXPLAIN ANALYZE query when enabled" do
          config.enable_explain_analyze = true
          sql = runner.send(:build_explain_query, valid_sql)
          
          expect(sql).to eq("EXPLAIN ANALYZE #{valid_sql}")
        end
      end
    end
  end
end
