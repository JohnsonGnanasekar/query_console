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
- ✅ Creates a file-based SQLite database (persists across requests)
- ✅ Seeds realistic test data (150 users with 15 columns, 300 posts with 12 columns)
- ✅ No authentication required (test mode)
- ✅ Ready for immediate testing
- ✅ Supports Hotwire (Turbo + Stimulus) for modern UI

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

The seed file creates realistic test data for comprehensive testing:

**Users Table:** (150 rows)
- **15 columns**: id, name, email, phone, department, role, salary, address, city, state, zip_code, active, last_login_at, created_at, updated_at
- Mix of active/inactive users
- Various departments: Engineering, Marketing, Sales, HR, Design, etc.
- Salary range: $42,000 - $150,000
- Random realistic addresses and contact info

**Posts Table:** (300 rows)
- **12 columns**: id, user_id, title, content, category, tags, view_count, like_count, published, published_at, created_at, updated_at
- Categories: Technology, Business, Lifestyle, Health, Education
- Mix of published and draft posts
- Random view counts (0-10,000) and like counts (0-500)

**Sample Queries Available:**
```sql
-- All users
SELECT * FROM users LIMIT 10;

-- High earners
SELECT name, email, role, salary FROM users WHERE salary > 100000;

-- By department
SELECT department, COUNT(*) as count FROM users GROUP BY department;

-- Join with posts
SELECT u.name, COUNT(p.id) as post_count 
FROM users u 
LEFT JOIN posts p ON u.id = p.user_id 
GROUP BY u.id 
ORDER BY post_count DESC 
LIMIT 10;

-- Popular posts
SELECT category, AVG(view_count) as avg_views 
FROM posts 
WHERE published = 1 
GROUP BY category;
```

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

## MVP Test Results

The QueryConsole gem has been comprehensively tested with automated browser tests using Playwright. **All 16 tests passed successfully:**

### ✅ Core Functionality (3 tests)
1. **Basic SELECT query** - 5 rows, 15 columns, execution time displayed
2. **WITH (CTE) query** - Common Table Expressions fully supported
3. **Complex JOIN with GROUP BY** - 5.13ms execution time, proper aggregation

### ✅ Security & Validation (5 tests)
4. **UPDATE blocked** - Clear error: "Query must start with one of: SELECT, WITH"
5. **DELETE blocked** - Same security error message
6. **DROP blocked** - Dangerous operations prevented
7. **Multiple statements blocked** - "Multiple statements are not allowed" error
8. **Empty query validation** - Alert shown: "Please enter a SQL query"

### ✅ UI/UX Features (4 tests)
9. **Clear button** - Empties textarea as expected
10. **Query history saved** - Automatically stores up to 20 queries in localStorage
11. **Load from history** - Click history item to populate editor
12. **Collapsible sections** - Banner, Editor, and History sections toggle independently

### ✅ Data Management (2 tests)
13. **Clear history** - Confirmation dialog, then clears all stored queries
14. **Horizontal/vertical scrolling** - Results table scrolls independently with sticky headers
15. **Row limit enforcement** - Shows max 100 rows (configurable) with warning banner
16. **Execution metadata** - Displays time, row count, and truncation notice

### Performance Metrics
- Simple queries: < 1ms execution time
- Complex JOINs: ~5ms execution time
- 150 rows with 15 columns renders smoothly
- Independent table scrolling works flawlessly

### UI Features Verified
- ✅ Turbo Frames for seamless result updates
- ✅ Stimulus controllers for interactivity
- ✅ localStorage persistence across sessions
- ✅ Responsive layout with mobile support
- ✅ Accessibility (keyboard navigation, ARIA labels)

## Next Steps

After testing locally:
1. Test in a real Rails app (see main README.md)
2. Test with your actual database schema
3. Test with your authentication system
4. Monitor logs in production (if enabled)
5. Customize max_rows and timeout_ms for your use case
