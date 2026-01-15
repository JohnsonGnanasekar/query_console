# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.2.0]: https://github.com/JohnsonGnanasekar/query_console/releases/tag/v0.2.0
[0.1.0]: https://github.com/JohnsonGnanasekar/query_console/releases/tag/v0.1.0
