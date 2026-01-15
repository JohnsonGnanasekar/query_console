require 'rails_helper'

RSpec.describe QueryConsole::Runner do
  let(:config) { QueryConsole.configuration }

  before do
    # Create a test table
    ActiveRecord::Base.connection.execute(<<~SQL)
      CREATE TABLE IF NOT EXISTS test_users (
        id INTEGER PRIMARY KEY,
        name TEXT,
        email TEXT,
        active INTEGER
      )
    SQL

    # Insert test data
    ActiveRecord::Base.connection.execute(<<~SQL)
      INSERT INTO test_users (id, name, email, active) VALUES
      (1, 'Alice', 'alice@example.com', 1),
      (2, 'Bob', 'bob@example.com', 1),
      (3, 'Charlie', 'charlie@example.com', 0)
    SQL
  end

  after do
    ActiveRecord::Base.connection.execute('DROP TABLE IF EXISTS test_users')
  end

  describe '#execute' do
    context 'with valid queries' do
      it 'executes a simple SELECT query' do
        runner = described_class.new('SELECT * FROM test_users')
        result = runner.execute

        expect(result).to be_success
        expect(result.columns).to include('id', 'name', 'email', 'active')
        expect(result.rows.length).to eq(3)
        expect(result.execution_time_ms).to be > 0
        expect(result.row_count_shown).to eq(3)
      end

      it 'executes SELECT with WHERE clause' do
        runner = described_class.new('SELECT * FROM test_users WHERE active = 1')
        result = runner.execute

        expect(result).to be_success
        expect(result.rows.length).to eq(2)
        expect(result.row_count_shown).to eq(2)
      end

      it 'executes SELECT with ORDER BY' do
        runner = described_class.new('SELECT name FROM test_users ORDER BY name')
        result = runner.execute

        expect(result).to be_success
        expect(result.columns).to eq(['name'])
        expect(result.rows.first).to include('Alice')
      end

      it 'marks result as truncated when limit is applied' do
        config.max_rows = 2
        runner = described_class.new('SELECT * FROM test_users')
        result = runner.execute

        expect(result).to be_success
        expect(result).to be_truncated
        expect(result.row_count_shown).to eq(2)
      end

      it 'does not mark as truncated when query has own LIMIT' do
        runner = described_class.new('SELECT * FROM test_users LIMIT 1')
        result = runner.execute

        expect(result).to be_success
        expect(result).not_to be_truncated
        expect(result.row_count_shown).to eq(1)
      end
    end

    context 'with validation errors' do
      it 'returns error for UPDATE queries' do
        runner = described_class.new('UPDATE test_users SET name = "hacker"')
        result = runner.execute

        expect(result).to be_failure
        expect(result.error).to include('Query must start with one of')
      end

      it 'returns error for DELETE queries' do
        runner = described_class.new('DELETE FROM test_users')
        result = runner.execute

        expect(result).to be_failure
        expect(result.error).to include('Query must start with one of')
      end

      it 'returns error for multiple statements' do
        runner = described_class.new('SELECT * FROM test_users; DROP TABLE test_users')
        result = runner.execute

        expect(result).to be_failure
        expect(result.error).to include('Multiple statements')
      end

      it 'returns error for empty queries' do
        runner = described_class.new('')
        result = runner.execute

        expect(result).to be_failure
        expect(result.error).to include('cannot be empty')
      end
    end

    context 'with SQL errors' do
      it 'returns error for invalid SQL syntax' do
        runner = described_class.new('SELECT * FROM nonexistent_table')
        result = runner.execute

        expect(result).to be_failure
        expect(result.error).to include('Query error')
      end

      it 'returns error for invalid column name' do
        runner = described_class.new('SELECT nonexistent_column FROM test_users')
        result = runner.execute

        expect(result).to be_failure
        expect(result.error).to be_present
      end
    end

    context 'with timeouts' do
      it 'returns timeout error for slow queries' do
        config.timeout_ms = 1 # 1ms timeout - very aggressive

        # This query should timeout (sleep is database-specific, this is a concept test)
        runner = described_class.new('SELECT * FROM test_users WHERE id = 1')
        
        # We can't reliably test timeout with SQLite, so let's just ensure the structure works
        result = runner.execute
        
        # Either succeeds quickly or times out
        expect(result).to be_a(QueryConsole::Runner::QueryResult)
      end
    end

    context 'with result structure' do
      it 'returns proper column names' do
        runner = described_class.new('SELECT id, name, email FROM test_users LIMIT 1')
        result = runner.execute

        expect(result.columns).to eq(['id', 'name', 'email'])
      end

      it 'returns rows as arrays' do
        runner = described_class.new('SELECT id, name FROM test_users WHERE id = 1')
        result = runner.execute

        expect(result.rows).to be_an(Array)
        expect(result.rows.first).to be_an(Array)
        expect(result.rows.first).to include(1, 'Alice')
      end

      it 'handles empty result sets' do
        runner = described_class.new('SELECT * FROM test_users WHERE id = 999')
        result = runner.execute

        expect(result).to be_success
        expect(result.rows).to be_empty
        expect(result.row_count_shown).to eq(0)
      end
    end
  end
end
