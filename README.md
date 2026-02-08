# QueryConsole

[![Gem Version](https://badge.fury.io/rb/query_console.svg)](https://badge.fury.io/rb/query_console)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](MIT-LICENSE)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.1-ruby.svg)](https://www.ruby-lang.org)
[![Rails](https://img.shields.io/badge/rails-%3E%3D%207.0-red.svg)](https://rubyonrails.org)

A Rails engine that provides a secure, mountable web interface for running SQL queries against your application's database. Read-only by default with optional DML support.

![Query Console Interface](https://via.placeholder.com/800x400/1e293b/ffffff?text=Query+Console+Interface)
*Modern, responsive SQL query interface with schema explorer and query management*

## Table of Contents

- [Features](#features)
- [Screenshots](#screenshots)
- [Security Features](#security-features)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Security Considerations](#security-considerations)
- [Development](#development)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [Changelog](#changelog)

## Features

### Security & Control
- 🔒 **Security First**: Read-only by default with multi-layer enforcement
- 🚦 **Environment Gating**: Disabled by default in production
- 🔑 **Flexible Authorization**: Integrate with your existing auth system
- ⚡ **Resource Protection**: Configurable row limits and query timeouts
- 📝 **Comprehensive Audit Logging**: All queries logged with actor information and metadata
- 🔐 **Optional DML Support**: Enable INSERT/UPDATE/DELETE with confirmation dialogs

### Query Execution
- 📊 **EXPLAIN Query Plans**: Analyze query execution plans for performance debugging
- ✅ **Smart Validation**: SQL validation with keyword blocking and statement isolation
- 🎯 **Accurate Results**: Proper row counts for both SELECT and DML operations
- ⏱️ **Query Timeout**: Configurable timeout to prevent long-running queries

### User Interface
- 📊 **Modern UI**: Clean, responsive interface with real-time updates
- 🗂️ **Schema Explorer**: Browse tables, columns, types with quick actions
- 💾 **Query Management**: Save, organize, import/export queries (client-side)
- 📜 **Query History**: Client-side history stored in browser localStorage
- 🎨 **Tabbed Navigation**: Switch between History, Schema, and Saved Queries seamlessly
- 🔍 **Quick Actions**: Generate queries from schema, copy names, insert WHERE clauses
- ⚡ **Hotwire-Powered**: Turbo Frames and Stimulus for smooth, SPA-like experience
- 🎨 **Zero Build Step**: CDN-hosted dependencies, no asset compilation needed

## Screenshots

### Query Execution
![Query Results](https://via.placeholder.com/800x400/1e293b/ffffff?text=Query+Execution+%26+Results)
*Execute SQL queries with real-time results, execution time, and row counts*

### DML Confirmation Dialog
![DML Confirmation](https://via.placeholder.com/600x300/ef4444/ffffff?text=DML+Confirmation+Dialog)
*Pre-execution confirmation for INSERT, UPDATE, DELETE operations with clear warnings*

### Schema Explorer
![Schema Browser](https://via.placeholder.com/800x400/1e293b/ffffff?text=Schema+Explorer)
*Browse database tables, columns, types with quick-action buttons*

### Query History & Management
![Query History](https://via.placeholder.com/800x400/1e293b/ffffff?text=Query+History+%26+Saved+Queries)
*Access recent queries and manage saved queries with tags and organization*

> **Note for Contributors**: Replace placeholder images with actual screenshots by adding PNG files to a `docs/images/` directory and updating the links above.

## Security Features

QueryConsole implements multiple layers of security:

1. **Environment Gating**: Only enabled in configured environments (development by default)
2. **Authorization Hook**: Requires explicit authorization configuration
3. **Read-Only by Default**: Only SELECT and WITH (CTE) queries allowed by default
4. **Optional DML with Safeguards**: INSERT/UPDATE/DELETE available when explicitly enabled, with mandatory user confirmation dialogs
5. **Keyword Blocking**: Always blocks DDL operations (DROP, ALTER, CREATE, TRUNCATE, etc.)
6. **Statement Isolation**: Prevents multiple statement execution
7. **Row Limiting**: Automatic result limiting to prevent resource exhaustion
8. **Query Timeout**: Configurable timeout to prevent long-running queries
9. **Comprehensive Audit Trail**: All queries logged with actor, query type, and execution metadata

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'query_console'
```

And then execute:

```bash
bundle install
rails generate query_console:install
```

**Requirements:**
- Ruby 3.1+
- Rails 7.0+
- Works with Rails 8+
- Hotwire (Turbo Rails + Stimulus) - automatically included

## Configuration

The generator creates `config/initializers/query_console.rb`. You **MUST** configure the authorization hook:

```ruby
QueryConsole.configure do |config|
  # Required: Set up authorization
  config.authorize = ->(controller) {
    controller.current_user&.admin?
  }

  # Track who runs queries
  config.current_actor = ->(controller) {
    controller.current_user&.email || "anonymous"
  }

  # Optional: Enable in additional environments (use with caution!)
  # config.enabled_environments = %w[development staging]

  # Optional: Adjust limits
  # config.max_rows = 1000
  # config.timeout_ms = 5000
  
  # Advanced Features
  # EXPLAIN feature (default: enabled)
  # config.enable_explain = true
  # config.enable_explain_analyze = false  # Disabled by default for safety
  
  # Schema Explorer (default: enabled)
  # config.schema_explorer = true
  # config.schema_cache_seconds = 60
  # config.schema_table_denylist = ["schema_migrations", "ar_internal_metadata"]
  # config.schema_allowlist = []  # Optional: whitelist specific tables
end
```

### Authorization Examples

#### With Devise

```ruby
config.authorize = ->(controller) {
  controller.current_user&.admin?
}
```

#### With HTTP Basic Auth

```ruby
config.authorize = ->(controller) {
  controller.authenticate_or_request_with_http_basic do |username, password|
    username == "admin" && password == Rails.application.credentials.query_console_password
  end
}
```

#### For Development (NOT for production!)

```ruby
config.authorize = ->(_controller) { true }
```

### Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `enabled_environments` | `["development"]` | Environments where console is accessible |
| `authorize` | `nil` | Lambda/proc that receives controller and returns true/false |
| `current_actor` | `->(_) { "unknown" }` | Lambda/proc to identify who's running queries |
| `max_rows` | `500` | Maximum rows returned per query |
| `timeout_ms` | `3000` | Query timeout in milliseconds |
| `forbidden_keywords` | See code | SQL keywords that are blocked |
| `allowed_starts_with` | `["select", "with"]` | Allowed query starting keywords |
| `enable_dml` | `false` | Enable DML queries (INSERT, UPDATE, DELETE) |
| `enable_explain` | `true` | Enable EXPLAIN query plans |
| `enable_explain_analyze` | `false` | Enable EXPLAIN ANALYZE (use with caution) |
| `schema_explorer` | `true` | Enable schema browser |
| `schema_cache_seconds` | `60` | Schema cache duration in seconds |

### DML (Data Manipulation Language) Support

By default, Query Console is **read-only**. To enable DML operations (INSERT, UPDATE, DELETE):

```ruby
QueryConsole.configure do |config|
  config.enable_dml = true
  
  # Recommended: Restrict to specific environments
  config.enabled_environments = ["development", "staging"]
end
```

#### Important Security Notes

- **DML is disabled by default** for safety
- When enabled, INSERT, UPDATE, DELETE, and MERGE queries are permitted
- All DML operations are logged with actor information and query type
- No transaction support - queries auto-commit immediately
- Consider additional application-level authorization for production use

#### What's Still Blocked

Even with DML enabled, these operations remain **forbidden**:
- `DROP`, `ALTER`, `CREATE` (schema changes)
- `TRUNCATE` (bulk deletion)
- `GRANT`, `REVOKE` (permission changes)
- `EXECUTE`, `EXEC` (stored procedures)
- `TRANSACTION`, `COMMIT`, `ROLLBACK` (manual transaction control)
- System procedures (`sp_`, `xp_`)

#### UI Behavior with DML

When DML is enabled and a DML query is detected:
- **Before execution**: A confirmation dialog appears with a clear warning about permanent data modifications
- User must explicitly confirm to proceed (can click "Cancel" to abort)
- **After execution**: An informational banner shows: "ℹ️ Data Modified: This query has modified the database"
- **Rows Affected** count is displayed (e.g., "3 row(s) affected") showing how many rows were inserted/updated/deleted
- The security banner reflects DML status
- All changes are permanent and logged

#### Database Support

DML operations work on all supported databases:
- **SQLite**: INSERT, UPDATE, DELETE
- **PostgreSQL**: INSERT, UPDATE, DELETE, MERGE (via INSERT ... ON CONFLICT)
- **MySQL**: INSERT, UPDATE, DELETE, REPLACE

#### Enhanced Audit Logging

DML queries are logged with additional metadata:

```ruby
{
  component: "query_console",
  actor: "user@example.com",
  sql: "UPDATE users SET active = true WHERE id = 123",
  duration_ms: 12.5,
  rows: 1,
  status: "ok",
  query_type: "UPDATE",     # NEW: Query type classification
  is_dml: true              # NEW: DML flag
}
```

#### Example DML Queries

```sql
-- Insert a new record
INSERT INTO users (name, email) VALUES ('John Doe', 'john@example.com');

-- Update existing records
UPDATE users SET active = true WHERE id = 123;

-- Delete specific records
DELETE FROM sessions WHERE expires_at < NOW();

-- PostgreSQL upsert
INSERT INTO settings (key, value) VALUES ('theme', 'dark')
ON CONFLICT (key) DO UPDATE SET value = 'dark';
```

## Mounting

Add to your `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  mount QueryConsole::Engine, at: "/query_console"
end
```

Then visit: `http://localhost:3000/query_console`

## Usage

### Running Queries

1. Enter your SELECT query in the editor
2. Click "Run Query" or press Ctrl/Cmd+Enter
3. View results in the table below
4. Query is automatically saved to history

### Query History

- Stored locally in your browser (not on server)
- Click any history item to load it into the editor
- Stores up to 20 recent queries
- Clear history with the "Clear" button

### Allowed Queries

✅ **Allowed**:
- `SELECT * FROM users`
- `SELECT id, name FROM users WHERE active = true`
- `WITH active_users AS (SELECT * FROM users WHERE active = true) SELECT * FROM active_users`
- Queries with JOINs, ORDER BY, GROUP BY, etc.

❌ **Blocked** (by default):
- `UPDATE users SET name = 'test'` (unless `enable_dml = true`)
- `DELETE FROM users` (unless `enable_dml = true`)
- `INSERT INTO users VALUES (...)` (unless `enable_dml = true`)
- `DROP TABLE users` (always blocked)
- `TRUNCATE TABLE users` (always blocked)
- `SELECT * FROM users; DELETE FROM users` (multiple statements always blocked)
- Any query containing forbidden keywords

**Note**: With `config.enable_dml = true`, INSERT, UPDATE, DELETE, and MERGE queries become allowed.

## Example Queries

```sql
-- List recent users
SELECT id, email, created_at 
FROM users 
ORDER BY created_at DESC 
LIMIT 10;

-- Count by status
SELECT status, COUNT(*) as count 
FROM orders 
GROUP BY status;

-- Join with aggregation
SELECT u.email, COUNT(o.id) as order_count
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.id, u.email
ORDER BY order_count DESC
LIMIT 20;

-- Common Table Expression (CTE)
WITH active_users AS (
  SELECT * FROM users WHERE active = true
)
SELECT * FROM active_users WHERE created_at > DATE('now', '-30 days');
```

## Security Considerations

### Environment Configuration

⚠️ **Important**: QueryConsole is **disabled by default in production**. To enable in non-development environments:

```ruby
config.enabled_environments = %w[development staging]
```

**Never enable in production without**:
1. Strong authentication
2. Network restrictions (VPN, IP whitelist)
3. Audit monitoring
4. Database read-only user (recommended)

### Authorization

The authorization hook is called on **every request**. Ensure it:
- Returns `false` or `nil` to deny access
- Is performant (avoid N+1 queries)
- Handles edge cases (logged out users, etc.)

### Audit Logs

All queries are logged to `Rails.logger.info` with:

```ruby
{
  component: "query_console",
  actor: "user@example.com",
  sql: "SELECT * FROM users LIMIT 10",
  duration_ms: 45.2,
  rows: 10,
  status: "ok",  # or "error"
  truncated: false
}
```

Monitor these logs for:
- Unusual query patterns
- Unauthorized access attempts
- Performance issues
- Data access patterns

### Database Permissions

For production environments, consider using a dedicated read-only database user:

```ruby
# config/database.yml
production_readonly:
  <<: *production
  username: readonly_user
  password: <%= ENV['READONLY_DB_PASSWORD'] %>

# In your initializer
QueryConsole.configure do |config|
  config.database_config = :production_readonly
end
```

## Development

### Testing Without a Rails App

You can test the gem in isolation without needing a full Rails application:

**Option 1: Run automated tests**
```bash
cd query_console
bundle install
bundle exec rspec
```

**Option 2: Start the test server**
```bash
cd query_console
bundle install
./bin/test_server
```

Then visit: http://localhost:9292/query_console

The test server includes sample data and is pre-configured for easy testing.

**See [TESTING.md](TESTING.md) for detailed testing instructions.**

### Test Coverage

The test suite includes:
- SQL validator specs (security rules)
- SQL limiter specs (result limiting)
- Runner specs (integration tests)
- Controller specs (authorization & routing)

## Frontend Technology Stack

QueryConsole uses **Hotwire (Turbo + Stimulus)**, the modern Rails-native frontend framework:

### What's Included

- **Turbo Frames**: Query results update without page reloads (SPA-like experience)
- **Stimulus Controllers**: Organized JavaScript for collapsible sections, history, and editor
- **CDN Delivery**: Hotwire loaded from CDN (no asset compilation needed)
- **Zero Build Step**: No webpack, esbuild, or other bundlers required

### Architecture

```
Frontend Stack
├── HTML: ERB Templates
├── CSS: Vanilla CSS (inline)
├── JavaScript: 
│   ├── Turbo Frames (results updates)
│   └── Stimulus Controllers
│       ├── collapsible_controller (section toggling)
│       ├── history_controller (localStorage management)
│       └── editor_controller (query execution)
└── Storage: localStorage API
```

### Benefits

✅ **No Build Step**: Works out of the box, no compilation needed  
✅ **Rails-Native**: Standard Rails 7+ approach  
✅ **Lightweight**: ~50KB total (vs React's 200KB+)  
✅ **Fast**: No page reloads, instant interactions  
✅ **Progressive**: Degrades gracefully without JavaScript  

### Why Hotwire?

1. **Rails Standard**: Default frontend stack for Rails 7+
2. **Simple**: Fewer moving parts than SPA frameworks
3. **Productive**: Write less JavaScript, more HTML
4. **Modern**: All the benefits of SPAs without the complexity
5. **Maintainable**: Standard Rails patterns throughout

## Troubleshooting

### Console returns 404

**Possible causes**:
1. Environment not in `enabled_environments`
2. Authorization hook returns `false`
3. Authorization hook not configured (defaults to deny)

**Solution**: Check your initializer configuration.

### Query times out

**Causes**:
- Query is too complex
- Database is slow
- Timeout setting too aggressive

**Solutions**:
- Increase `timeout_ms`
- Optimize query
- Add indexes to database

### "Multiple statements" error

**Cause**: Query contains semicolon (`;`) in the middle

**Solution**: Remove extra semicolons. Only one trailing semicolon is allowed.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Write tests for your changes
4. Ensure tests pass (`bundle exec rspec`)
5. Commit your changes (`git commit -am 'Add feature'`)
6. Push to the branch (`git push origin feature/my-feature`)
7. Create a Pull Request

## License

The gem is available as open source under the terms of the [MIT License](MIT-LICENSE).

## Credits

Created by [Johnson Gnanasekar](https://github.com/JohnsonGnanasekar)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

### Recent Updates

#### Latest (DML Support)
- ✨ **Optional DML Support**: INSERT/UPDATE/DELETE with mandatory confirmation dialogs
- 🎯 **Accurate Row Counts**: Proper affected rows tracking for DML operations
- 🔒 **Enhanced Security**: Pre-execution confirmation with detailed warnings
- 📝 **Enhanced Audit Logging**: Query type classification and DML flags
- 🗃️ **Multi-Database Support**: SQLite, PostgreSQL, MySQL compatibility

#### v0.2.0 (January 2026)
- 📊 **EXPLAIN Plans**: Query execution plan analysis
- 🗂️ **Schema Explorer**: Interactive table/column browser with quick actions
- 💾 **Saved Queries**: Client-side query management with import/export
- 🎨 **Modern UI**: Tabbed navigation and collapsible sections
- 🔍 **Quick Actions**: Generate queries from schema explorer

#### v0.1.0 (Initial Release)
- 🔒 Read-only query console with security enforcement
- 🚦 Environment gating and authorization hooks
- ✅ SQL validation and row limiting
- ⏱️ Query timeout protection
- 📜 Client-side history with localStorage
- ✅ Comprehensive test suite and audit logging
