# Create some test data for manual testing

ActiveRecord::Base.connection.execute(<<~SQL)
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    role TEXT,
    active INTEGER DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )
SQL

ActiveRecord::Base.connection.execute(<<~SQL)
  CREATE TABLE IF NOT EXISTS posts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    title TEXT NOT NULL,
    content TEXT,
    published INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )
SQL

# Insert sample users
users = [
  ["Alice Johnson", "alice@example.com", "admin", 1],
  ["Bob Smith", "bob@example.com", "user", 1],
  ["Charlie Brown", "charlie@example.com", "user", 1],
  ["Diana Prince", "diana@example.com", "moderator", 1],
  ["Eve Wilson", "eve@example.com", "user", 0]
]

users.each do |name, email, role, active|
  ActiveRecord::Base.connection.execute(
    "INSERT INTO users (name, email, role, active) VALUES (?, ?, ?, ?)",
    name, email, role, active
  )
end

# Insert sample posts
posts = [
  [1, "Getting Started with Rails", "This is a great introduction...", 1],
  [1, "Advanced SQL Tips", "Here are some advanced techniques...", 1],
  [2, "My First Blog Post", "Welcome to my blog!", 1],
  [2, "Draft Post", "This is not published yet...", 0],
  [3, "Ruby Best Practices", "Let me share some tips...", 1],
  [4, "Security in Rails", "Security is important...", 1]
]

posts.each do |user_id, title, content, published|
  ActiveRecord::Base.connection.execute(
    "INSERT INTO posts (user_id, title, content, published) VALUES (?, ?, ?, ?)",
    user_id, title, content, published
  )
end

puts "✅ Created 5 users and 6 posts for testing"
puts ""
puts "Sample queries to try:"
puts "  SELECT * FROM users;"
puts "  SELECT * FROM users WHERE active = 1;"
puts "  SELECT name, email, role FROM users ORDER BY name;"
puts "  SELECT u.name, COUNT(p.id) as post_count FROM users u LEFT JOIN posts p ON u.id = p.user_id GROUP BY u.id;"
puts "  WITH active_users AS (SELECT * FROM users WHERE active = 1) SELECT * FROM active_users;"
