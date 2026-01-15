# QueryConsole - Quick Start Guide

## Test Without a Rails App (Recommended)

### 1. Clone and Setup
```bash
git clone https://github.com/JohnsonGnanasekar/query_console.git
cd query_console
bundle install
```

### 2. Run the Test Server
```bash
./bin/test_server
```

### 3. Open Your Browser
Visit: **http://localhost:9292/query_console**

You'll see a SQL query console with:
- ✅ Sample database with users and posts tables
- ✅ Query editor with syntax highlighting
- ✅ Real-time query execution
- ✅ Query history (localStorage)
- ✅ Beautiful results table

### 4. Try Sample Queries

**Basic:**
```sql
SELECT * FROM users;
SELECT * FROM posts WHERE published = 1;
```

**With Joins:**
```sql
SELECT u.name, COUNT(p.id) as post_count
FROM users u
LEFT JOIN posts p ON u.id = p.user_id
GROUP BY u.id;
```

**With CTEs:**
```sql
WITH active_users AS (
  SELECT * FROM users WHERE active = 1
)
SELECT * FROM active_users;
```

**Test Security (Should Fail):**
```sql
UPDATE users SET name = 'Hacked';
DELETE FROM users;
DROP TABLE users;
```

## Run Automated Tests

```bash
bundle exec rspec
```

Expected output:
```
QueryConsole::SqlValidator
  #validate
    with valid SELECT queries
      ✓ allows simple SELECT queries
      ✓ allows SELECT with WHERE clause
      ... (40+ more tests)

Finished in 0.5 seconds
40+ examples, 0 failures
```

## Use in a Real Rails App

### 1. Add to Gemfile
```ruby
gem 'query_console', git: 'https://github.com/JohnsonGnanasekar/query_console.git'
```

### 2. Install
```bash
bundle install
rails generate query_console:install
```

### 3. Configure (config/initializers/query_console.rb)
```ruby
QueryConsole.configure do |config|
  # REQUIRED: Set authorization
  config.authorize = ->(controller) {
    controller.current_user&.admin?
  }
  
  # Track who runs queries
  config.current_actor = ->(controller) {
    controller.current_user&.email || "anonymous"
  }
end
```

### 4. Mount in routes.rb
```ruby
Rails.application.routes.draw do
  mount QueryConsole::Engine, at: "/query_console"
end
```

### 5. Visit
http://localhost:3000/query_console

## Key Features

| Feature | Description |
|---------|-------------|
| 🔒 **Secure** | Read-only by default, blocks write operations |
| 🚦 **Environment Gating** | Development only by default |
| 🔑 **Authorization** | Integrate with your auth system |
| 📊 **Modern UI** | Clean interface with history |
| 📝 **Audit Logs** | All queries logged |
| ⚡ **Resource Protection** | Row limits and timeouts |

## Configuration Options

```ruby
QueryConsole.configure do |config|
  config.enabled_environments = %w[development]  # Where it's enabled
  config.max_rows = 500                          # Max results
  config.timeout_ms = 3000                       # Query timeout
  config.authorize = ->(c) { true }              # Auth hook
  config.current_actor = ->(c) { "user" }        # Who's querying
end
```

## Security

QueryConsole enforces security at multiple levels:

1. ✅ Environment gating (dev only by default)
2. ✅ Authorization hook required
3. ✅ Only SELECT/WITH queries allowed
4. ✅ Forbidden keyword blocking
5. ✅ Multiple statement prevention
6. ✅ Row limiting (configurable)
7. ✅ Query timeout (configurable)
8. ✅ Full audit logging

## Support

- **GitHub**: https://github.com/JohnsonGnanasekar/query_console
- **Issues**: https://github.com/JohnsonGnanasekar/query_console/issues
- **Documentation**: See README.md and TESTING.md

## License

MIT License - See MIT-LICENSE file
