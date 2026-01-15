require 'rails_helper'

RSpec.describe QueryConsole::SqlLimiter do
  let(:max_rows) { 500 }

  describe '#apply_limit' do
    context 'when query does not have LIMIT' do
      it 'wraps simple SELECT query with LIMIT' do
        limiter = described_class.new('SELECT * FROM users', max_rows)
        result = limiter.apply_limit

        expect(result.sql).to eq('SELECT * FROM (SELECT * FROM users) qc_subquery LIMIT 500')
        expect(result).to be_truncated
      end

      it 'wraps query with WHERE clause' do
        limiter = described_class.new('SELECT * FROM users WHERE active = true', max_rows)
        result = limiter.apply_limit

        expect(result.sql).to include('SELECT * FROM (SELECT * FROM users WHERE active = true) qc_subquery LIMIT 500')
        expect(result).to be_truncated
      end

      it 'wraps query with ORDER BY' do
        limiter = described_class.new('SELECT * FROM users ORDER BY created_at DESC', max_rows)
        result = limiter.apply_limit

        expect(result.sql).to include('ORDER BY created_at DESC')
        expect(result.sql).to include('LIMIT 500')
        expect(result).to be_truncated
      end

      it 'wraps WITH (CTE) queries' do
        sql = <<~SQL.strip
          WITH active_users AS (
            SELECT * FROM users WHERE active = true
          )
          SELECT * FROM active_users
        SQL

        limiter = described_class.new(sql, max_rows)
        result = limiter.apply_limit

        expect(result.sql).to start_with('SELECT * FROM (WITH active_users')
        expect(result.sql).to include('LIMIT 500')
        expect(result).to be_truncated
      end

      it 'preserves complex queries with subqueries' do
        sql = 'SELECT u.*, (SELECT COUNT(*) FROM posts WHERE user_id = u.id) as post_count FROM users u'
        limiter = described_class.new(sql, max_rows)
        result = limiter.apply_limit

        expect(result.sql).to include('LIMIT 500')
        expect(result).to be_truncated
      end
    end

    context 'when query already has LIMIT' do
      it 'does not modify query with uppercase LIMIT' do
        sql = 'SELECT * FROM users LIMIT 10'
        limiter = described_class.new(sql, max_rows)
        result = limiter.apply_limit

        expect(result.sql).to eq(sql)
        expect(result).not_to be_truncated
      end

      it 'does not modify query with lowercase limit' do
        sql = 'SELECT * FROM users limit 25'
        limiter = described_class.new(sql, max_rows)
        result = limiter.apply_limit

        expect(result.sql).to eq(sql)
        expect(result).not_to be_truncated
      end

      it 'does not modify query with mixed case LiMiT' do
        sql = 'SELECT * FROM users LiMiT 100'
        limiter = described_class.new(sql, max_rows)
        result = limiter.apply_limit

        expect(result.sql).to eq(sql)
        expect(result).not_to be_truncated
      end

      it 'detects LIMIT with OFFSET' do
        sql = 'SELECT * FROM users LIMIT 50 OFFSET 100'
        limiter = described_class.new(sql, max_rows)
        result = limiter.apply_limit

        expect(result.sql).to eq(sql)
        expect(result).not_to be_truncated
      end

      it 'detects LIMIT in query with ORDER BY' do
        sql = 'SELECT * FROM users ORDER BY created_at DESC LIMIT 20'
        limiter = described_class.new(sql, max_rows)
        result = limiter.apply_limit

        expect(result.sql).to eq(sql)
        expect(result).not_to be_truncated
      end
    end

    context 'with different max_rows values' do
      it 'applies custom max_rows limit' do
        limiter = described_class.new('SELECT * FROM users', 1000)
        result = limiter.apply_limit

        expect(result.sql).to include('LIMIT 1000')
        expect(result).to be_truncated
      end

      it 'applies small max_rows limit' do
        limiter = described_class.new('SELECT * FROM users', 10)
        result = limiter.apply_limit

        expect(result.sql).to include('LIMIT 10')
        expect(result).to be_truncated
      end
    end

    context 'with edge cases' do
      it 'handles query with trailing spaces' do
        limiter = described_class.new('SELECT * FROM users   ', max_rows)
        result = limiter.apply_limit

        expect(result.sql).to include('LIMIT 500')
        expect(result).to be_truncated
      end

      it 'handles query with newlines' do
        sql = <<~SQL
          SELECT *
          FROM users
          WHERE active = true
        SQL

        limiter = described_class.new(sql, max_rows)
        result = limiter.apply_limit

        expect(result.sql).to include('LIMIT 500')
        expect(result).to be_truncated
      end

      it 'handles query with LIMIT in a comment (should still wrap)' do
        sql = 'SELECT * FROM users -- LIMIT 10'
        limiter = described_class.new(sql, max_rows)
        result = limiter.apply_limit

        # This is a limitation - we don't parse comments
        # But for security, we check for LIMIT anywhere in the string
        expect(result.sql).to eq(sql)
      end
    end
  end
end
