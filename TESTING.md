# Testing QueryConsole

This guide shows you how to test the QueryConsole gem without needing a full Rails application.

## Quick Start

There are three ways to test the gem:

### Option 1: Run RSpec Tests (Fastest)

```bash
cd query_console
bundle install
bundle exec rspec
```

This runs the complete test suite with 40+ test cases covering:
- SQL validation and security
- Row limiting
- Query execution
- Error handling

### Option 2: Interactive Test Server (Best for UI Testing)

```bash
cd query_console
bundle install
./bin/test_server
```

Then visit: **http://localhost:9292/query_console**

The test server:
- ✅ Runs a minimal Rails app with the gem mounted
- ✅ Creates an in-memory SQLite database
- ✅ Seeds sample data (5 users, 6 posts)
- ✅ No authentication required (test mode)
- ✅ Ready for immediate testing

### Option 3: Rails Console (For API Testing)

```bash
cd query_console
bundle install
cd spec/dummy
rails console
```

Then test the gem programmatically:

```ruby
# Configure
QueryConsole.configure do |config|
  config.enabled_environments = %w[development test]
  config.authorize = ->(_) { true }
end

# Create test data
ActiveRecord::Base.connection.execute(<<~SQL)
  CREATE TABLE users (id INTEGER, name TEXT)
SQL

ActiveRecord::Base.connection.execute(
  "INSERT INTO users VALUES (1, 'Alice')"
)

# Test validator
validator = QueryConsole::SqlValidator.new("SELECT * FROM users")
result = validator.validate
puts result.valid? # => true

# Test runner
runner = QueryConsole::Runner.new("SELECT * FROM users")
result = runner.execute
puts result.columns # => ["id", "name"]
puts result.rows    # => [[1, "Alice"]]
```

## Sample Queries for UI Testing

Once the test server is running, try these queries:

### Basic Queries
```sql
SELECT * FROM users;
SELECT * FROM posts;
SELECT name, email FROM users WHERE active = 1;
```

### Joins
```sql
SELECT u.name, p.title 
FROM users u 
JOIN posts p ON u.id = p.user_id;

SELECT u.name, COUNT(p.id) as post_count
FROM users u
LEFT JOIN posts p ON u.id = p.user_id
GROUP BY u.id, u.name;
```

### CTEs (Common Table Expressions)
```sql
WITH active_users AS (
  SELECT * FROM users WHERE active = 1
)
SELECT * FROM active_users;
```

### Security Tests (Should Fail)
```sql
-- These should be BLOCKED:
UPDATE users SET name = 'Hacker';
DELETE FROM users;
DROP TABLE users;
SELECT * FROM users; DELETE FROM posts;
```

## Test Data

The seed file creates:

**Users Table:**
- 5 users (4 active, 1 inactive)
- Columns: id, name, email, role, active, created_at

**Posts Table:**
- 6 posts (5 published, 1 draft)
- Columns: id, user_id, title, content, published, created_at

## Testing Different Scenarios

### Test Environment Gating

Edit `spec/dummy/config/initializers/query_console.rb`:

```ruby
# This will block access (should return 404)
config.enabled_environments = %w[production]
```

Restart server and try to access the console.

### Test Authorization

```ruby
# This will deny access (should return 404)
config.authorize = ->(_controller) { false }
```

### Test Row Limiting

```ruby
# Set a small limit to see truncation warning
config.max_rows = 3
```

Run: `SELECT * FROM users;` (should only show 3 rows)

### Test Timeout

```ruby
# Set aggressive timeout
config.timeout_ms = 1
```

Try a complex query to trigger timeout.

## Debugging

### View Logs

The test server logs all queries. Watch for:

```ruby
{
  component: "query_console",
  actor: "test_user",
  sql: "SELECT * FROM users",
  duration_ms: 2.5,
  rows: 5,
  status: "ok"
}
```

### Test Individual Components

```ruby
# In Rails console
config = QueryConsole.configuration

# Test validator
validator = QueryConsole::SqlValidator.new("SELECT * FROM users", config)
puts validator.validate.inspect

# Test limiter
limiter = QueryConsole::SqlLimiter.new("SELECT * FROM users", 10, config)
puts limiter.apply_limit.inspect

# Test runner
runner = QueryConsole::Runner.new("SELECT * FROM users", config)
puts runner.execute.inspect
```

## Running Specific Tests

```bash
# All tests
bundle exec rspec

# Just validator tests
bundle exec rspec spec/services/sql_validator_spec.rb

# Just limiter tests
bundle exec rspec spec/services/sql_limiter_spec.rb

# Just runner tests
bundle exec rspec spec/services/runner_spec.rb

# Single test
bundle exec rspec spec/services/sql_validator_spec.rb:10
```

## Continuous Testing

Use Guard for automatic test running:

```bash
# Add to Gemfile
gem 'guard-rspec'

bundle install
guard init rspec
bundle exec guard
```

Now tests run automatically when you change files.

## Performance Testing

Test query execution time:

```ruby
require 'benchmark'

sql = "SELECT * FROM users JOIN posts ON users.id = posts.user_id"
runner = QueryConsole::Runner.new(sql)

time = Benchmark.measure { runner.execute }
puts "Execution time: #{time.real}s"
```

## Memory Testing

Check memory usage with large result sets:

```ruby
# Create large dataset
1000.times do |i|
  ActiveRecord::Base.connection.execute(
    "INSERT INTO users (name, email, role, active) VALUES (?, ?, ?, ?)",
    "User #{i}", "user#{i}@example.com", "user", 1
  )
end

# Test with different max_rows
config.max_rows = 100
runner = QueryConsole::Runner.new("SELECT * FROM users")
result = runner.execute
puts "Memory used: #{result.rows.size * result.columns.size * 50} bytes (estimate)"
```

## CI/CD Integration

For GitHub Actions:

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.2
          bundler-cache: true
      - run: bundle exec rspec
```

## Troubleshooting

### "Cannot find gem"
```bash
cd query_console
bundle install
```

### "Database locked"
The in-memory database should prevent this, but if it happens:
```bash
rm spec/dummy/db/*.sqlite3
```

### "Port already in use"
Change the port in `bin/test_server`:
```ruby
Rack::Handler::WEBrick.run(app, Port: 9293, ...)
```

### "Authorization failed"
Check `spec/dummy/config/initializers/query_console.rb`:
```ruby
config.authorize = ->(_controller) { true }
```

## Next Steps

After testing locally:
1. Test in a real Rails app (see main README.md)
2. Test with your actual database schema
3. Test with your authentication system
4. Monitor logs in production (if enabled)
