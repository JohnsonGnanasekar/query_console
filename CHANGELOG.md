# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

### Version 0.2.0 (Planned)
- [ ] Syntax highlighting for SQL
- [ ] Query auto-completion
- [ ] Export results (CSV, JSON)
- [ ] Saved queries (server-side storage)
- [ ] Query sharing via URL
- [ ] Dark mode support
- [ ] Internationalization (i18n)

### Version 0.3.0 (Planned)
- [ ] Query performance analysis
- [ ] Visual query builder
- [ ] Schema browser
- [ ] Query templates
- [ ] User preferences
- [ ] Multiple database connections

---

**Contributors**: [Johnson Gnanasekar](https://github.com/JohnsonGnanasekar)

[0.1.0]: https://github.com/JohnsonGnanasekar/query_console/releases/tag/v0.1.0
