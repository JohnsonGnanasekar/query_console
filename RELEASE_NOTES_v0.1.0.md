# QueryConsole v0.1.0 - Initial MVP Release 🎉

**Release Date**: January 15, 2026  
**Git Tag**: v0.1.0  
**Commit**: 407bcb6

---

## 📦 Published Gem

**🎉 Now available on RubyGems.org!**

[![Gem Version](https://badge.fury.io/rb/query_console.svg)](https://badge.fury.io/rb/query_console)

- **Install**: `gem install query_console`
- **RubyGems Page**: https://rubygems.org/gems/query_console
- **Version**: 0.1.0
- **License**: MIT

---

## 🌟 What is QueryConsole?

QueryConsole is a secure, mountable Rails engine that provides a web-based interface for running read-only SQL queries against your application's database. Perfect for development, debugging, and safe database exploration.

---

## ✨ Key Features

### 🔐 Security First
- **Multi-Layer Validation**: Only SELECT and WITH (CTE) queries allowed
- **Keyword Blocking**: Automatically blocks UPDATE, DELETE, INSERT, DROP, and other dangerous operations
- **Environment Gating**: Disabled by default in production
- **Authorization Hooks**: Integrate with any authentication system
- **Audit Logging**: All queries logged with actor information
- **Row Limiting**: Default 100-row limit prevents resource exhaustion
- **Query Timeout**: 3-second default timeout with configuration

### ⚡ Modern User Experience
- **Hotwire-Powered**: Uses Turbo Frames and Stimulus for SPA-like experience
- **Zero Build Step**: JavaScript loaded via CDN, works out of the box
- **Query History**: Stores up to 20 recent queries in browser localStorage
- **Collapsible UI**: Toggle banner, editor, and history sections
- **Independent Scrolling**: Results table scrolls horizontally and vertically
- **Real-Time Metrics**: Displays execution time, row count, truncation warnings
- **Responsive Design**: Works on desktop, tablet, and mobile

### 🚀 Performance
- **Sub-Millisecond Queries**: Simple queries execute in < 1ms
- **Efficient JOINs**: Complex queries with JOINs ~5ms
- **Smooth Rendering**: Handles 150 rows × 15 columns effortlessly
- **Turbo Frames**: No page reloads, instant result updates

---

## 📦 Installation

**Available on RubyGems**: https://rubygems.org/gems/query_console

```ruby
# Add to Gemfile
gem 'query_console', '~> 0.1.0'

# Install
bundle install

# Generate initializer
rails generate query_console:install

# Configure authorization (required!)
# Edit config/initializers/query_console.rb
QueryConsole.configure do |config|
  config.authorize = ->(controller) { controller.current_user&.admin? }
  config.current_actor = ->(controller) { controller.current_user&.email || "unknown" }
end

# Mount in routes
# Edit config/routes.rb
mount QueryConsole::Engine, at: "/query_console"
```

**Visit**: http://localhost:3000/query_console

---

## 🧪 Testing & Quality

### All 16 Automated Tests Passed ✅

**Core Functionality (3/3)**
- ✅ SELECT queries with multiple columns
- ✅ WITH (CTE) Common Table Expressions
- ✅ Complex JOINs with GROUP BY

**Security Validation (5/5)**
- ✅ UPDATE statements blocked
- ✅ DELETE statements blocked
- ✅ DROP statements blocked
- ✅ Multiple statements blocked
- ✅ Empty query validation

**UI/UX Features (4/4)**
- ✅ Clear button functionality
- ✅ Query history (localStorage)
- ✅ Load queries from history
- ✅ Collapsible sections

**Data Management (4/4)**
- ✅ Clear history with confirmation
- ✅ Independent table scrolling
- ✅ Row limit enforcement
- ✅ Execution metadata display

### Test Coverage
- **40+ RSpec Tests**: Comprehensive coverage of all features
- **Automated UI Tests**: Playwright-based browser testing
- **Performance Benchmarks**: Documented execution times

---

## 📚 Documentation

- **[README.md](README.md)** - Complete installation and usage guide
- **[TESTING.md](TESTING.md)** - Comprehensive testing documentation with MVP results
- **[QUICKSTART.md](QUICKSTART.md)** - 60-second quick start guide
- **[TEST_SUMMARY.md](TEST_SUMMARY.md)** - Detailed test report with metrics
- **[CHANGELOG.md](CHANGELOG.md)** - Full release notes and roadmap

---

## 🔐 Security Considerations

### ⚠️ Important: Production Use

QueryConsole is **disabled by default in production**. If you enable it in production:

1. **Use Strong Authentication**: Require admin-level access
2. **Network Restrictions**: Use VPN or IP whitelist
3. **Monitor Audit Logs**: Track all query executions
4. **Read-Only DB User**: Consider a dedicated read-only database user

### Security Features
- Environment-based enabling (development only by default)
- Configurable authorization hooks
- SQL injection prevention (no multiple statements)
- Dangerous keyword blocking (UPDATE, DELETE, DROP, etc.)
- Query timeout protection
- Row limiting to prevent resource exhaustion
- Structured audit logging

---

## 🎯 Use Cases

### Development
- Debug database queries
- Explore data schema
- Test JOIN performance
- Verify data integrity
- Quick data lookups

### Staging/QA
- Investigate production issues (with proper auth)
- Verify data migrations
- Check data consistency
- Support team queries (with authorization)

### Production (With Caution)
- Emergency data lookups
- Customer support queries
- Data verification
- Performance investigation

---

## 💻 Technical Requirements

- **Ruby**: 3.1+
- **Rails**: 7.0+ (including Rails 8.x)
- **Database**: SQLite, PostgreSQL, MySQL, or any ActiveRecord-compatible database
- **Browser**: Modern browsers with ES6 support (Chrome, Firefox, Safari, Edge)

---

## 🚀 Quick Start Example

```ruby
# After installation, try these queries:

# Basic query
SELECT * FROM users LIMIT 10;

# With filtering
SELECT name, email FROM users WHERE active = true;

# Aggregation
SELECT department, COUNT(*) as count 
FROM users 
GROUP BY department;

# JOIN
SELECT u.name, COUNT(p.id) as post_count
FROM users u
LEFT JOIN posts p ON u.id = p.user_id
GROUP BY u.id;

# CTE (Common Table Expression)
WITH active_users AS (
  SELECT * FROM users WHERE active = true
)
SELECT * FROM active_users;
```

---

## 🗺️ Roadmap

### Version 0.2.0 (Next)
- Syntax highlighting for SQL
- Query auto-completion
- Export results (CSV, JSON)
- Saved queries (server-side)
- Dark mode support

### Version 0.3.0 (Future)
- Visual query builder
- Schema browser
- Query performance analysis
- Multiple database connections
- User preferences

---

## 📊 What's New in v0.1.0

### Added
- ✨ Complete read-only SQL query interface
- 🔐 Multi-layer security validation
- ⚡ Hotwire (Turbo + Stimulus) frontend
- 📝 Client-side query history (localStorage)
- 📊 Real-time execution metrics
- 🎨 Modern, responsive UI
- 📋 Comprehensive audit logging
- 🧪 Full test suite (40+ tests)
- 📚 Complete documentation

### Technical Implementation
- Rails Engine with isolated namespace
- Turbo Frames for seamless updates
- Stimulus controllers for interactivity
- SQL validation service layer
- Query limiting and timeout protection
- Audit logging service

---

## 🙏 Acknowledgments

Built with love using:
- **Rails** - Web framework
- **Hotwire** - Modern frontend (Turbo + Stimulus)
- **RSpec** - Testing framework
- **Playwright** - Automated UI testing
- **SQLite** - Development database

---

## 📄 License

MIT License - See [MIT-LICENSE](MIT-LICENSE) file for details.

---

## 🔗 Links

- **RubyGems**: https://rubygems.org/gems/query_console
- **Repository**: https://github.com/JohnsonGnanasekar/query_console
- **Issues**: https://github.com/JohnsonGnanasekar/query_console/issues
- **Releases**: https://github.com/JohnsonGnanasekar/query_console/releases
- **Documentation**: https://github.com/JohnsonGnanasekar/query_console/blob/main/README.md

---

## 📞 Support

- **Issues**: Report bugs or request features via GitHub Issues
- **Discussions**: Join community discussions on GitHub
- **Documentation**: See README.md, TESTING.md, and QUICKSTART.md

---

**Created by**: [Johnson Gnanasekar](https://github.com/JohnsonGnanasekar)  
**Release Date**: January 15, 2026  
**Version**: 0.1.0
