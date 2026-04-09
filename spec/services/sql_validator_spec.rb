require 'rails_helper'

RSpec.describe QueryConsole::SqlValidator do
  let(:config) { QueryConsole.configuration }

  describe '#validate' do
    context 'with valid SELECT queries' do
      it 'allows simple SELECT queries' do
        validator = described_class.new('SELECT * FROM users')
        result = validator.validate

        expect(result).to be_valid
        expect(result.sanitized_sql).to eq('SELECT * FROM users')
      end

      it 'allows SELECT with WHERE clause' do
        validator = described_class.new('SELECT id, name FROM users WHERE active = true')
        result = validator.validate

        expect(result).to be_valid
      end

      it 'allows SELECT with JOINs' do
        validator = described_class.new('SELECT u.*, p.name FROM users u JOIN profiles p ON u.id = p.user_id')
        result = validator.validate

        expect(result).to be_valid
      end

      it 'allows SELECT with ORDER BY and LIMIT' do
        validator = described_class.new('SELECT * FROM users ORDER BY created_at DESC LIMIT 10')
        result = validator.validate

        expect(result).to be_valid
      end

      it 'allows case-insensitive SELECT' do
        validator = described_class.new('select * from users')
        result = validator.validate

        expect(result).to be_valid
      end

      it 'allows SELECT with single trailing semicolon' do
        validator = described_class.new('SELECT * FROM users;')
        result = validator.validate

        expect(result).to be_valid
        expect(result.sanitized_sql).to eq('SELECT * FROM users')
      end

      it 'allows SELECT with trailing whitespace and semicolon' do
        validator = described_class.new("SELECT * FROM users;  \n  ")
        result = validator.validate

        expect(result).to be_valid
        expect(result.sanitized_sql).to eq('SELECT * FROM users')
      end
    end

    context 'with valid WITH (CTE) queries' do
      it 'allows WITH queries' do
        sql = <<~SQL
          WITH active_users AS (
            SELECT * FROM users WHERE active = true
          )
          SELECT * FROM active_users
        SQL
        
        validator = described_class.new(sql)
        result = validator.validate

        expect(result).to be_valid
      end

      it 'allows case-insensitive WITH' do
        validator = described_class.new('with temp as (select 1) select * from temp')
        result = validator.validate

        expect(result).to be_valid
      end
    end

    context 'with write operations' do
      it 'blocks UPDATE queries' do
        validator = described_class.new('UPDATE users SET name = "hacker"')
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('Query must start with one of')
      end

      it 'blocks DELETE queries' do
        validator = described_class.new('DELETE FROM users')
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('Query must start with one of')
      end

      it 'blocks INSERT queries' do
        validator = described_class.new('INSERT INTO users (name) VALUES ("hacker")')
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('Query must start with one of')
      end

      it 'blocks DROP queries' do
        validator = described_class.new('DROP TABLE users')
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('Query must start with one of')
      end

      it 'blocks ALTER queries' do
        validator = described_class.new('ALTER TABLE users ADD COLUMN hacked BOOLEAN')
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('Query must start with one of')
      end

      it 'blocks CREATE queries' do
        validator = described_class.new('CREATE TABLE malicious (id INT)')
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('Query must start with one of')
      end

      it 'blocks TRUNCATE queries' do
        validator = described_class.new('TRUNCATE TABLE users')
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('Query must start with one of')
      end
    end

    context 'with forbidden keywords even in SELECT' do
      it 'blocks SELECT with UPDATE keyword' do
        validator = described_class.new('SELECT * FROM users WHERE name = "update"')
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('UPDATE')
      end

      it 'blocks SELECT with DELETE keyword' do
        validator = described_class.new('SELECT * FROM users; DELETE FROM users')
        result = validator.validate

        expect(result).to be_invalid
      end
    end

    context 'with multiple statements' do
      it 'blocks queries with multiple semicolons' do
        validator = described_class.new('SELECT * FROM users; SELECT * FROM posts')
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('Multiple statements')
      end

      it 'blocks SQL injection attempts' do
        validator = described_class.new('SELECT * FROM users WHERE id = 1; DROP TABLE users;')
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('Multiple statements')
      end

      it 'blocks queries with semicolon in the middle' do
        validator = described_class.new('SELECT * FROM users WHERE name = "test"; DROP TABLE users')
        result = validator.validate

        expect(result).to be_invalid
      end
    end

    context 'with queries not starting with allowed keywords' do
      it 'blocks queries starting with EXPLAIN' do
        validator = described_class.new('EXPLAIN SELECT * FROM users')
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('must start with')
      end

      it 'blocks queries starting with SHOW' do
        validator = described_class.new('SHOW TABLES')
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('must start with')
      end
    end

    context 'with empty or invalid input' do
      it 'rejects empty queries' do
        validator = described_class.new('')
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('cannot be empty')
      end

      it 'rejects nil queries' do
        validator = described_class.new(nil)
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('cannot be empty')
      end

      it 'rejects whitespace-only queries' do
        validator = described_class.new("   \n  \t  ")
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('cannot be empty')
      end
    end

    context 'with stored procedures and dangerous operations' do
      it 'blocks EXECUTE statements' do
        validator = described_class.new('EXECUTE sp_something')
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('Query must start with one of')
      end

      it 'blocks GRANT statements' do
        validator = described_class.new('GRANT ALL ON users TO hacker')
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('Query must start with one of')
      end

      it 'blocks REVOKE statements' do
        validator = described_class.new('REVOKE ALL ON users FROM admin')
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('Query must start with one of')
      end
    end

    context 'with DML enabled (enable_dml = true)' do
      before do
        config.enable_dml = true
      end

      after do
        config.enable_dml = false
      end

      it 'allows INSERT queries' do
        validator = described_class.new("INSERT INTO users (name, email) VALUES ('John', 'john@example.com')")
        result = validator.validate

        expect(result).to be_valid
        expect(result).to be_dml
        expect(result.sanitized_sql).to include('INSERT INTO users')
      end

      it 'allows UPDATE queries' do
        validator = described_class.new('UPDATE users SET active = true WHERE id = 1')
        result = validator.validate

        expect(result).to be_valid
        expect(result).to be_dml
        expect(result.sanitized_sql).to include('UPDATE users')
      end

      it 'allows DELETE queries' do
        validator = described_class.new('DELETE FROM sessions WHERE expires_at < NOW()')
        result = validator.validate

        expect(result).to be_valid
        expect(result).to be_dml
        expect(result.sanitized_sql).to include('DELETE FROM sessions')
      end

      it 'allows MERGE queries' do
        validator = described_class.new('MERGE INTO users USING new_users ON users.id = new_users.id')
        result = validator.validate

        expect(result).to be_valid
        expect(result).to be_dml
      end

      it 'still blocks DROP queries' do
        validator = described_class.new('DROP TABLE users')
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('Query must start with one of')
      end

      it 'still blocks TRUNCATE queries' do
        validator = described_class.new('TRUNCATE TABLE users')
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('Query must start with one of')
      end

      it 'still blocks ALTER queries' do
        validator = described_class.new('ALTER TABLE users ADD COLUMN hacked BOOLEAN')
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('Query must start with one of')
      end

      it 'still blocks CREATE queries' do
        validator = described_class.new('CREATE TABLE malicious (id INT)')
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('Query must start with one of')
      end

      it 'still blocks GRANT queries' do
        validator = described_class.new('GRANT ALL ON users TO hacker')
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('Query must start with one of')
      end

      it 'still blocks EXECUTE queries' do
        validator = described_class.new('EXECUTE sp_something')
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('Query must start with one of')
      end

      it 'marks SELECT queries as non-DML' do
        validator = described_class.new('SELECT * FROM users')
        result = validator.validate

        expect(result).to be_valid
        expect(result).not_to be_dml
      end

      it 'marks WITH queries as non-DML' do
        validator = described_class.new('WITH temp AS (SELECT 1) SELECT * FROM temp')
        result = validator.validate

        expect(result).to be_valid
        expect(result).not_to be_dml
      end
    end

    context 'with DML disabled (enable_dml = false)' do
      before do
        config.enable_dml = false
      end

      it 'blocks INSERT queries' do
        validator = described_class.new("INSERT INTO users (name) VALUES ('test')")
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('Query must start with one of')
      end

      it 'blocks UPDATE queries' do
        validator = described_class.new('UPDATE users SET name = "test" WHERE id = 1')
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('Query must start with one of')
      end

      it 'blocks DELETE queries' do
        validator = described_class.new('DELETE FROM users WHERE id = 1')
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('Query must start with one of')
      end

      it 'blocks MERGE queries' do
        validator = described_class.new('MERGE INTO users USING new_users ON users.id = new_users.id')
        result = validator.validate

        expect(result).to be_invalid
        expect(result.error).to include('Query must start with one of')
      end

      it 'allows SELECT queries' do
        validator = described_class.new('SELECT * FROM users')
        result = validator.validate

        expect(result).to be_valid
        expect(result).not_to be_dml
      end

      it 'allows WITH queries' do
        validator = described_class.new('WITH temp AS (SELECT 1) SELECT * FROM temp')
        result = validator.validate

        expect(result).to be_valid
        expect(result).not_to be_dml
      end
    end

    # SECURITY TESTS: Subquery DML Bypass
    context 'security: subquery DML bypass prevention' do
      let(:config) do
        config = QueryConsole::Configuration.new
        config.enable_dml = true
        config
      end

      it 'blocks DELETE in subquery when DML enabled' do
        sql = 'SELECT * FROM (DELETE FROM users RETURNING *) AS x'
        validator = described_class.new(sql, config)
        result = validator.validate

        expect(result).not_to be_valid
        expect(result.error).to include('DML keywords')
        expect(result.error).to include('subqueries')
      end

      it 'blocks UPDATE in subquery when DML enabled' do
        sql = 'SELECT * FROM (UPDATE users SET name = \'x\' RETURNING *) AS x'
        validator = described_class.new(sql, config)
        result = validator.validate

        expect(result).not_to be_valid
        expect(result.error).to include('DML keywords')
        expect(result.error).to include('subqueries')
      end

      it 'blocks INSERT in subquery when DML enabled' do
        sql = 'SELECT * FROM (INSERT INTO users (name) VALUES (\'x\') RETURNING *) AS x'
        validator = described_class.new(sql, config)
        result = validator.validate

        expect(result).not_to be_valid
        expect(result.error).to include('DML keywords')
        expect(result.error).to include('subqueries')
      end

      it 'blocks DELETE in WITH clause when DML enabled' do
        sql = 'WITH deleted AS (DELETE FROM users RETURNING *) SELECT * FROM deleted'
        validator = described_class.new(sql, config)
        result = validator.validate

        expect(result).not_to be_valid
        expect(result.error).to include('DML keywords')
        expect(result.error).to include('WITH clauses')
      end

      it 'allows top-level DELETE when DML enabled' do
        sql = 'DELETE FROM users WHERE id = 1'
        validator = described_class.new(sql, config)
        result = validator.validate

        expect(result).to be_valid
        expect(result).to be_dml
      end

      it 'allows top-level INSERT when DML enabled' do
        sql = 'INSERT INTO users (name) VALUES (\'test\')'
        validator = described_class.new(sql, config)
        result = validator.validate

        expect(result).to be_valid
        expect(result).to be_dml
      end

      it 'blocks SELECT with DML keyword in string literal (conservative security)' do
        # NOTE: This is a conservative security measure. Even though 'delete' is in a
        # string literal, we block it to prevent sophisticated SQL injection attacks.
        # A full SQL parser would be needed to allow this safely.
        sql = 'SELECT * FROM users WHERE name = \'delete\''
        validator = described_class.new(sql, config)
        result = validator.validate

        expect(result).not_to be_valid
        expect(result.error).to include('DML keywords')
      end

      it 'allows SELECT with table/column names containing DML-like words' do
        # Table/column names like "deleted_at" or "updates" are OK
        # as long as they're not exact DML keyword matches
        sql = 'SELECT deleted_at, last_updated FROM users'
        validator = described_class.new(sql, config)
        result = validator.validate

        expect(result).to be_valid
        expect(result).not_to be_dml
      end
    end
  end
end
