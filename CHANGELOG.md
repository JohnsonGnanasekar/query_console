# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.4] - 2026-02-10

### ⚡ Improved - Safer Query Timeout Strategy

#### Configurable Timeout Strategy
- **Added** `config.timeout_strategy` option with three modes:
  - `:database` - Database-level timeout (PostgreSQL `statement_timeout`) - safer, no orphan queries
  - `:ruby` - Ruby-level timeout (`Timeout.timeout`) - fallback for non-PostgreSQL databases
  - `nil` (default) - Auto-detect: use database timeout for PostgreSQL, Ruby timeout for others

#### Problem Solved: Orphan Query Issue
**The Ruby Timeout Problem:**
- When using `Timeout.timeout`, the Ruby thread is interrupted
- **BUT the database query continues running** as an orphan process
- Database connection is returned to pool, but query still executes
- Can cause resource exhaustion and blocking locks

**Database Timeout Solution:**
- Database itself cancels the query using `SET LOCAL statement_timeout`
- Clean termination at the DB level
- No orphan queries
- Scoped to transaction only - doesn't affect other connections

#### Technical Implementation

**Runner and ExplainRunner now support three timeout methods:**

1. **Database Timeout (PostgreSQL):**
```ruby
conn.transaction do
  conn.execute("SET LOCAL statement_timeout = '#{timeout_ms}'")
  conn.exec_query(sql)
end
```

2. **Ruby Timeout (Fallback):**
```ruby
Timeout.timeout(timeout_seconds) do
  ActiveRecord::Base.connection.exec_query(sql)
end
```

3. **Auto-Detection (Default):**
- Detects PostgreSQL adapter → uses database timeout
- Other adapters (SQLite, MySQL) → uses Ruby timeout with warning

#### Configuration

```ruby
QueryConsole.configure do |config|
  # Recommended for PostgreSQL (default: auto-detect)
  config.timeout_strategy = :database
  
  # Or explicitly use Ruby timeout (not recommended for PostgreSQL)
  config.timeout_strategy = :ruby
  
  # Or let it auto-detect (nil)
  config.timeout_strategy = nil # default
  
  config.timeout_ms = 5000 # 5 seconds
end
```

#### Benefits
- ✅ **No orphan queries** with database-level timeout
- ✅ **Cleaner resource management** - database handles cancellation
- ✅ **Backward compatible** - Ruby timeout still available as fallback
- ✅ **Auto-detection** - works out of the box for all databases
- ✅ **Transaction-scoped** - `SET LOCAL` doesn't affect other connections

#### Notes
- PostgreSQL 9.0+ required for `statement_timeout` support
- SQLite and MySQL use Ruby timeout (no equivalent to `SET LOCAL statement_timeout`)
- Warning logged when database timeout requested for non-PostgreSQL adapters

## [0.2.3] - 2026-02-10

### 🔒 Security - Fixed CSRF Protection

#### Fixed Unconditional CSRF Skip
- **Problem**: `QueriesController` and `ExplainController` unconditionally disabled CSRF protection for POST actions, leaving them vulnerable to CSRF attacks
- **Solution**: Removed unconditional `skip_forgery_protection` from both controllers
- **Protection**: Now relies on `ApplicationController`'s conditional CSRF skip that only exempts Turbo-Frame requests (which include proper authentication)

#### Technical Details
- Removed `skip_forgery_protection only: [:run]` from `QueriesController`
- Removed `skip_forgery_protection only: [:create]` from `ExplainController`
- The base `ApplicationController` already has proper CSRF protection:
  - `protect_from_forgery with: :exception, prepend: true`
  - `skip_forgery_protection if: -> { request.headers['Turbo-Frame'].present? }`
- UI forms include `authenticity_token` and `data-turbo-frame` attributes for proper Turbo integration

#### Security Impact
- ✅ Non-Turbo POST requests now require valid CSRF token
- ✅ Turbo-Frame requests (normal UI usage) continue to work correctly
- ✅ Raw curl/API requests without CSRF token are now properly rejected
- ✅ No impact on legitimate users - UI includes proper CSRF tokens

#### Testing
- All 102 service specs pass
- Updated `ExplainController` spec to include `Turbo-Frame` header in test requests
- Verified UI forms include both `authenticity_token` and `data-turbo-frame`

## [0.2.2] - 2026-02-10

### 🔧 Fixed

#### Dependency Improvements
- **Removed hard importmap-rails dependency**: The gem no longer forces host applications to install `importmap-rails` when using other JavaScript bundlers (esbuild, webpack, vite, etc.)
- **Made importmap integration optional**: The importmap initializer now conditionally loads only if `Importmap` is defined in the host app
- **Self-contained UI**: The query console UI uses inline importmaps with CDN scripts, making it fully functional without the Rails importmap system

#### Technical Details
- Removed `spec.add_dependency "importmap-rails", "~> 2.0"` from gemspec
- Updated `query_console.importmap` initializer to check for `defined?(Importmap)` before attempting to register the importmap config
- The `config/importmap.rb` file remains for apps that do use importmap-rails (optional convenience)
- Host apps using esbuild, webpack, or other bundlers no longer need to install an unnecessary dependency

### 🎯 Benefits
- Smaller dependency footprint for apps not using importmap
- Better compatibility with modern JavaScript bundlers
- No breaking changes - existing importmap-based apps continue to work as before

## [0.2.1] - 2026-02-09

### 🔐 Security Enhancement - DML Support

This release adds optional Data Manipulation Language (DML) support with comprehensive safety features and user confirmation workflows.

### ✨ New Features

#### 1. Optional DML Support 🔐
- **Configuration Toggle**: Enable/disable DML via `config.enable_dml` (default: `false`)
- **Supported Operations**: INSERT, UPDATE, DELETE, MERGE (PostgreSQL)
- **Pre-Execution Confirmation**: Mandatory JavaScript confirmation dialog before DML execution
- **Clear Warnings**: Explicit warnings about permanent data modifications
- **User Cancellation**: Users can safely cancel DML operations without side effects
- **Multi-Database Support**: Works with SQLite, PostgreSQL, MySQL

#### 2. Enhanced User Experience 🎯
- **Pre-Execution Dialog**: 
  - Appears before any DML query is sent to the server
  - Clear warning about permanent changes
  - "Proceed" or "Cancel" options
  - Lists all DML operations being performed
- **Post-Execution Banner**: 
  - Informational message after successful DML execution
  - Uses past tense: "This query has modified the database"
  - Includes logging confirmation
- **Accurate Row Counts**: 
  - Displays "Rows Affected: X" for DML operations
  - Shows "X row(s) affected" in results area
  - Database-specific implementations (SQLite, PostgreSQL, MySQL)

#### 3. Security Enhancements 🔒
- **Read-Only by Default**: DML is disabled unless explicitly enabled
- **Granular Control**: Can enable DML only in specific environments
- **DDL Still Blocked**: DROP, ALTER, CREATE, TRUNCATE always forbidden
- **Enhanced Validation**: Conditional keyword validation based on DML setting
- **Query Type Detection**: Automatic DML detection at multiple layers

#### 4. Enhanced Audit Logging 📝
- **Query Type Classification**: All queries tagged with type (SELECT, INSERT, UPDATE, DELETE)
- **DML Flag**: Boolean `is_dml` flag for easy filtering
- **Affected Rows Count**: Logged with each DML operation
- **Actor Tracking**: All DML operations tracked to specific users

### 🔧 Implementation Details

#### New Configuration
```ruby
QueryConsole.configure do |config|
  config.enable_dml = true
  config.enabled_environments = ["development", "staging"]  # Recommended
end
```

#### Database Adapter Support
- **SQLite**: `raw_connection.changes` for affected rows
- **PostgreSQL**: `result.cmd_tuples` for affected rows  
- **MySQL**: `result.affected_rows` for affected rows

#### Modified Components
- `SqlValidator`: Conditional DML keyword validation
- `SqlLimiter`: Skip LIMIT wrapping for DML queries
- `Runner`: Track affected rows using adapter-specific methods
- `AuditLogger`: Enhanced with `query_type` and `is_dml` fields
- `QueriesController`: Pass DML flag to views
- JavaScript: Client-side confirmation dialogs

### 🧪 Testing

#### Browser Integration Tests (All Passing)
- ✅ INSERT with confirmation dialog
- ✅ UPDATE with multi-row affected count
- ✅ DELETE with affected rows display
- ✅ Confirmation cancellation (no execution)
- ✅ DDL still blocked (DROP, TRUNCATE)
- ✅ No regression in SELECT functionality

#### RSpec Unit Tests (All Passing)
- ✅ DML validation with config enabled/disabled
- ✅ SqlLimiter skips wrapping for DML
- ✅ Runner tracks affected rows correctly
- ✅ AuditLogger includes query type metadata

### 📝 UI Behavior

**Before Execution:**
```
⚠️ DATA MODIFICATION WARNING

This query will INSERT, UPDATE, or DELETE data.

• All changes are PERMANENT and cannot be undone
• All operations are logged

Do you want to proceed?

[Cancel] [OK]
```

**After Execution:**
```
ℹ️ Data Modified: This query has modified the database. 
All changes are logged.

Execution Time: 1.2ms
Rows Affected: 3

3 row(s) affected
```

### ⚠️ What's Still Blocked

Even with `enable_dml = true`, these operations remain **forbidden**:
- `DROP`, `ALTER`, `CREATE` (schema changes)
- `TRUNCATE` (bulk deletion)
- `GRANT`, `REVOKE` (permission changes)
- `EXECUTE`, `EXEC` (stored procedures)
- `TRANSACTION`, `COMMIT`, `ROLLBACK` (manual transaction control)

### 🔄 Backwards Compatibility

- ✅ All existing features maintained
- ✅ Read-only behavior unchanged by default
- ✅ No breaking changes
- ✅ Seamless upgrade path

### 📦 Upgrade Guide

```bash
# Update Gemfile
gem 'query_console', '~> 0.2.1'

# Install
bundle update query_console

# Optional: Enable DML in initializer
QueryConsole.configure do |config|
  config.enable_dml = true  # Default: false
end
```

### 🐛 Bug Fixes

- Fixed partial paths in `ExplainController` for consistency
- Improved row count display for SELECT vs DML operations
- Enhanced error messages for query validation

### 📝 Known Limitations

- No transaction support (queries auto-commit)
- Cannot batch multiple DML statements
- Confirmation dialog requires JavaScript

### 🔗 Links

- **Documentation**: See README.md DML section
- **Security Notes**: See Security Considerations section

---

## [0.2.0] - 2026-01-15

### 🚀 Feature Release

This release adds powerful new features for performance debugging, schema exploration, and enhanced editing capabilities - all while maintaining the zero-build-step philosophy.

### ✨ New Features

#### 1. EXPLAIN Query Plans 📊
- **Performance Debugging**: Analyze query execution plans without executing the full query
- **Database Adapter Support**: Works with PostgreSQL, MySQL, and SQLite
- **Safety First**: EXPLAIN is server-side generated (users can't inject unsafe EXPLAIN ANALYZE)
- **Configuration**: Enable/disable EXPLAIN feature via `enable_explain` (default: true)
- **ANALYZE Mode**: Optional EXPLAIN ANALYZE (disabled by default via `enable_explain_analyze`)
- **UI**: Dedicated "Explain" button with keyboard shortcut (Shift+Cmd/Ctrl+Enter)
- **Results**: Human-readable query plan with execution time

#### 2. Schema Explorer 🗂️
- **Live Schema Introspection**: Browse tables, columns, types, and metadata
- **Search & Filter**: Quickly find tables with real-time search
- **Column Details**: View column names, types, nullable status, and defaults
- **Quick Actions**: 
  - Generate SELECT queries from table/column selection
  - Copy table/column names to clipboard
  - Insert WHERE clauses with column templates
- **Caching**: Configurable schema caching (default 60 seconds) for performance
- **Security**: Denylist support to hide internal tables (schema_migrations, etc.)
- **JSON API**: RESTful endpoints for schema data (`GET /schema/tables`, `GET /schema/tables/:name`)

#### 3. Enhanced SQL Editor 📝
- **Textarea Editor**: Professional monospace editor with proper formatting
- **Keyboard Shortcuts**:
  - `Cmd/Ctrl + Enter`: Run Query
  - `Shift + Cmd/Ctrl + Enter`: Explain Query
  - `Cmd/Ctrl + L`: Clear Editor
  - `Tab`: Insert 2 spaces (maintains focus)
- **Integration**: Seamless integration with Schema Explorer quick actions
- **Visual Polish**: Improved styling, focus states, and placeholder text

#### 4. Saved Queries 💾
- **Client-Side Storage**: Save important queries in localStorage
- **Organization**: Name queries and tag them for easy discovery
- **Import/Export**: Full JSON import/export for backup and sharing
- **Quick Access**: Load saved queries with one click
- **Management**: Rename, delete, and manage your query library
- **No Migrations**: Zero database impact, all client-side

#### 5. Modern UI Overhaul 🎨
- **Tabbed Right Panel**: Switch between History and Schema views
- **Collapsible Sections**: Banner, Saved Queries minimize to save space
- **Grid Layout**: Optimized layout with 3-column design
- **Professional Styling**: Refined colors, spacing, and typography
- **Turbo Integration**: Seamless partial updates without full page reloads

### 🔧 Configuration Updates

#### New Configuration Options
```ruby
QueryConsole.configure do |config|
  # EXPLAIN feature toggle
  config.enable_explain = true              # Enable/disable EXPLAIN button (default: true)
  config.enable_explain_analyze = false     # Allow EXPLAIN ANALYZE (default: false)
  
  # Schema Explorer settings
  config.schema_explorer = true             # Enable/disable schema explorer (default: true)
  config.schema_cache_seconds = 60          # Schema cache duration (default: 60)
  config.schema_table_denylist = [          # Tables to hide (default: migrations)
    "schema_migrations",
    "ar_internal_metadata"
  ]
  config.schema_allowlist = []              # Optional: whitelist specific tables (default: [])
end
```

### 🏗️ Technical Implementation

#### New Services
- `QueryConsole::ExplainRunner` - Adapter-aware EXPLAIN execution
- `QueryConsole::SchemaIntrospector` - Database schema introspection with caching

#### New Controllers
- `QueryConsole::ExplainController` - Handles EXPLAIN requests
- `QueryConsole::SchemaController` - JSON API for schema data

#### New Routes
- `POST /explain` - Execute EXPLAIN for a query
- `GET /schema/tables` - List all accessible tables
- `GET /schema/tables/:name` - Get column details for a table

#### UI Architecture
- Stimulus Controllers: Tabs, Schema, Saved Queries, Editor enhancements
- Turbo Frames: Async updates for results and explain output
- localStorage: `query_console.saved.v1` for saved queries

### 📊 Tested Features

#### Playwright End-to-End Tests (All Passing)
- ✅ Run Query: 10 rows × 15 columns in 1.03ms
- ✅ Schema Explorer: Lists tables (users, posts)
- ✅ Schema Details: Shows all 15 columns with types
- ✅ Quick Actions: SELECT * FROM insertion works
- ✅ EXPLAIN: Query plan display in 0.67ms
- ✅ Saved Queries: UI implemented and functional
- ✅ Keyboard Shortcuts: All shortcuts working
- ✅ Collapsible Sections: All panels toggle correctly

#### RSpec Tests
- ✅ ExplainRunner: Adapter detection, validation, timeout
- ✅ SchemaIntrospector: Table listing, column details, caching
- ✅ Existing tests: All core functionality maintained

### 🔄 Backwards Compatibility

- ✅ All v0.1.0 features maintained
- ✅ Existing configuration continues to work
- ✅ No breaking changes to API or behavior
- ✅ Upgrade is seamless - just bundle update

### 📦 Upgrade Guide

```bash
# Update Gemfile
gem 'query_console', '~> 0.2.0'

# Install
bundle update query_console

# Optional: Add new config options to config/initializers/query_console.rb
# (All new options have sensible defaults)
```

### ⚠️ Note on CodeMirror

Initially planned CodeMirror 6 integration was postponed due to CDN dependency complexity. The current enhanced textarea provides all core functionality with zero build requirements. CodeMirror may be added in a future release with proper bundling.

### 🐛 Bug Fixes

- Fixed audit logger to handle both QueryResult and ExplainResult
- Improved error handling for schema introspection
- Enhanced authorization flow consistency across all endpoints

### 📝 Known Limitations

- Saved queries are client-side only (not synced across browsers)
- Schema Explorer shows structure only (no data preview)
- EXPLAIN ANALYZE is disabled by default for safety
- CodeMirror syntax highlighting not included (textarea instead)

### 🙏 Acknowledgments

Special thanks to the Rails and Hotwire communities for their excellent documentation and tools.

---

## [0.1.0] - 2026-01-15

### 🎉 Initial MVP Release

This is the first public release of QueryConsole - a secure, read-only SQL query interface for Rails applications.

### ✨ Features

#### Core Functionality
- **Read-Only SQL Execution**: Execute SELECT and WITH (CTE) queries against your database
- **Mountable Rails Engine**: Easy integration into any Rails 7+ application
- **Modern UI**: Clean, responsive interface with Hotwire (Turbo + Stimulus)
- **Query History**: Client-side storage of up to 20 recent queries in localStorage
- **Real-Time Execution**: Sub-millisecond query execution with Turbo Frames

#### Security Features
- **Environment Gating**: Disabled by default in production, explicit opt-in required
- **Authorization Hooks**: Flexible integration with any authentication system
- **SQL Validation**: Multi-layer validation blocking UPDATE, DELETE, INSERT, DROP
- **Statement Isolation**: Prevents multiple statement execution (SQL injection protection)
- **Row Limiting**: Automatic result limiting to prevent resource exhaustion (default 100 rows)
- **Query Timeout**: Configurable timeout protection (default 3000ms)
- **Audit Logging**: Structured logging of all query executions with actor tracking

#### UI/UX Features
- **Collapsible Sections**: Banner, Editor, and History sections can be toggled
- **Independent Scrolling**: Results table scrolls horizontally and vertically independently
- **Execution Metrics**: Display of execution time, row count, and truncation warnings
- **Error Messages**: Clear, user-friendly error messages for security violations
- **Keyboard Shortcuts**: Support for common keyboard interactions
- **Mobile Responsive**: Works on desktop, tablet, and mobile devices

#### Technical Implementation
- **Rails 7.0+ Compatible**: Works with Rails 7.x and Rails 8.x
- **Hotwire-Powered**: Uses Turbo Frames and Stimulus for SPA-like experience
- **Zero Build Step**: JavaScript loaded via CDN, no asset compilation needed
- **SQLite/PostgreSQL/MySQL**: Compatible with all major databases
- **Comprehensive Tests**: 40+ RSpec tests covering all features

### 📊 Test Coverage

#### Automated Tests (16/16 Passed)
- ✅ Core functionality (SELECT, WITH/CTE, JOINs)
- ✅ Security validation (blocks UPDATE, DELETE, DROP, multiple statements)
- ✅ UI/UX features (history, collapsible sections, scrolling)
- ✅ Data management (row limiting, timeout enforcement)

#### Performance Metrics
- Simple queries: < 1ms execution time
- Complex JOINs: ~5ms execution time
- 150 rows × 15 columns: Smooth rendering with independent scrolling

### 📦 What's Included

#### Core Files
- `app/controllers/` - Query execution controllers with authorization
- `app/services/` - SQL validation, limiting, and execution services
- `app/views/` - ERB templates with Hotwire integration
- `config/` - Engine configuration and routes
- `lib/` - Configuration DSL and gem setup

#### Documentation
- `README.md` - Complete installation and usage guide
- `TESTING.md` - Comprehensive testing documentation with MVP results
- `QUICKSTART.md` - 60-second quick start guide
- `TEST_SUMMARY.md` - Detailed test report
- `CHANGELOG.md` - This file

#### Testing Infrastructure
- `spec/` - 40+ RSpec tests
- `bin/test_server` - Standalone test server for development
- Enhanced seed data (150 users, 300 posts) for realistic testing

### 🚀 Getting Started

```bash
# Add to Gemfile
gem 'query_console', '~> 0.1.0'

# Install and generate initializer
bundle install
rails generate query_console:install

# Configure authorization in config/initializers/query_console.rb
QueryConsole.configure do |config|
  config.authorize = ->(controller) { controller.current_user&.admin? }
end

# Mount in routes
mount QueryConsole::Engine, at: "/query_console"
```

### 🔐 Security Considerations

**Important**: This gem is designed for development and staging environments. If enabling in production:
- Use strong authentication
- Implement network restrictions (VPN, IP whitelist)
- Monitor audit logs
- Consider using a read-only database user

### 📝 Known Limitations

- Client-side history only (not synced across devices)
- No query saving/sharing features
- Basic syntax highlighting (planned for future)
- English language only (i18n planned for future)

### 🙏 Acknowledgments

Built with:
- **Rails** - The web framework
- **Hotwire** - Modern frontend framework
- **RSpec** - Testing framework
- **Playwright** - Automated UI testing

### 📄 License

MIT License - See [MIT-LICENSE](MIT-LICENSE) file for details.

### 🔗 Links

- **Repository**: https://github.com/JohnsonGnanasekar/query_console
- **Issues**: https://github.com/JohnsonGnanasekar/query_console/issues
- **Documentation**: See README.md, TESTING.md, QUICKSTART.md

---

## Upcoming Features (Roadmap)

### Version 0.3.0 (Planned)
- [ ] Export results (CSV, JSON)
- [ ] Saved queries with server-side storage
- [ ] Query sharing via URL
- [ ] Dark mode support
- [ ] CodeMirror 6 syntax highlighting & autocomplete
- [ ] Query performance analysis dashboard
- [ ] Visual query builder
- [ ] Query templates & snippets
- [ ] User preferences persistence
- [ ] Multiple database connections
- [ ] Internationalization (i18n)

---

**Contributors**: [Johnson Gnanasekar](https://github.com/JohnsonGnanasekar)

[0.2.4]: https://github.com/JohnsonGnanasekar/query_console/releases/tag/v0.2.4
[0.2.3]: https://github.com/JohnsonGnanasekar/query_console/releases/tag/v0.2.3
[0.2.2]: https://github.com/JohnsonGnanasekar/query_console/releases/tag/v0.2.2
[0.2.1]: https://github.com/JohnsonGnanasekar/query_console/releases/tag/v0.2.1
[0.2.0]: https://github.com/JohnsonGnanasekar/query_console/releases/tag/v0.2.0
[0.1.0]: https://github.com/JohnsonGnanasekar/query_console/releases/tag/v0.1.0
