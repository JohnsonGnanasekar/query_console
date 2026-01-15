# QueryConsole - Quick Start Guide

**Get started with QueryConsole in 60 seconds!**

## 1. Start the Test Server

```bash
cd query_console
bundle install
./bin/test_server
```

Visit: **http://localhost:9292/query_console**

## 2. Try These Queries

### ✅ Basic Query
```sql
SELECT * FROM users LIMIT 5;
```

### ✅ Filtering & Sorting
```sql
SELECT name, email, salary 
FROM users 
WHERE department = 'Engineering' 
ORDER BY salary DESC;
```

### ✅ Aggregation
```sql
SELECT department, COUNT(*) as employee_count, AVG(salary) as avg_salary
FROM users 
GROUP BY department
ORDER BY avg_salary DESC;
```

### ✅ JOIN
```sql
SELECT u.name, COUNT(p.id) as post_count
FROM users u
LEFT JOIN posts p ON u.id = p.user_id
GROUP BY u.id, u.name
ORDER BY post_count DESC
LIMIT 10;
```

### ✅ CTE (Common Table Expression)
```sql
WITH high_earners AS (
  SELECT * FROM users WHERE salary > 100000
)
SELECT department, COUNT(*) as count
FROM high_earners
GROUP BY department;
```

## 3. Test Security (These Should Fail)

```sql
-- ❌ Update blocked
UPDATE users SET name = 'Hacker';

-- ❌ Delete blocked
DELETE FROM users;

-- ❌ Drop blocked
DROP TABLE users;

-- ❌ Multiple statements blocked
SELECT * FROM users; DELETE FROM users;
```

## 4. Explore the UI

- **Query History**: Automatically saved (up to 20 queries)
- **Load from History**: Click any history item to reuse a query
- **Clear History**: Click the "Clear" button in the history panel
- **Collapsible Sections**: Toggle banner, editor, or history visibility
- **Independent Scrolling**: Results table scrolls horizontally and vertically

## 5. Test Row Limiting

```sql
-- Try querying all users (150 in database)
SELECT * FROM users;

-- Default limit is 100 rows
-- You'll see: "⚠ Results limited to 100 rows"
```

## 6. Check the Features

✅ **Real-time execution**: Results appear instantly (via Turbo Frames)  
✅ **Execution metrics**: Time and row count displayed  
✅ **Security**: Only SELECT and WITH queries allowed  
✅ **Performance**: Sub-millisecond for simple queries  
✅ **Modern UI**: Hotwire-powered (Turbo + Stimulus)  

## Available Test Data

- **150 Users**: 15 columns including name, email, department, salary, etc.
- **300 Posts**: 12 columns including title, category, view_count, etc.

## Configuration

To test different settings, edit:
```
spec/dummy/config/initializers/query_console.rb
```

```ruby
QueryConsole.configure do |config|
  # Try different limits
  config.max_rows = 50  # Default: 100
  
  # Adjust timeout
  config.timeout_ms = 10000  # Default: 3000
  
  # Test authorization (always true for testing)
  config.authorize = ->(_controller) { true }
end
```

Restart the server after changes.

## Need More Help?

- **Full Testing Guide**: See [TESTING.md](TESTING.md)
- **Complete Documentation**: See [README.md](README.md)
- **MVP Test Results**: See [TESTING.md#mvp-test-results](TESTING.md#mvp-test-results)

---

**That's it! You're ready to explore QueryConsole! 🚀**
