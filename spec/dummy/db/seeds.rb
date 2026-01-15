# Create some test data for manual testing

ActiveRecord::Base.connection.execute(<<~SQL)
  DROP TABLE IF EXISTS users
SQL

ActiveRecord::Base.connection.execute(<<~SQL)
  DROP TABLE IF EXISTS posts
SQL

ActiveRecord::Base.connection.execute(<<~SQL)
  CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT,
    department TEXT,
    role TEXT,
    salary REAL,
    address TEXT,
    city TEXT,
    state TEXT,
    zip_code TEXT,
    active INTEGER DEFAULT 1,
    last_login_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )
SQL

ActiveRecord::Base.connection.execute(<<~SQL)
  CREATE TABLE posts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    title TEXT NOT NULL,
    content TEXT,
    category TEXT,
    tags TEXT,
    view_count INTEGER DEFAULT 0,
    like_count INTEGER DEFAULT 0,
    published INTEGER DEFAULT 0,
    published_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )
SQL

# Generate realistic test data
puts "🌱 Seeding database..."

# Sample data arrays
first_names = ["Alice", "Bob", "Charlie", "Diana", "Eve", "Frank", "Grace", "Henry", "Iris", "Jack",
               "Kate", "Liam", "Maya", "Noah", "Olivia", "Peter", "Quinn", "Rachel", "Sam", "Tina"]
last_names = ["Johnson", "Smith", "Brown", "Prince", "Wilson", "Davis", "Miller", "Garcia", "Martinez", "Lopez",
              "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin", "Lee", "Walker", "Hall", "Allen"]
departments = ["Engineering", "Sales", "Marketing", "HR", "Finance", "Operations", "Support", "Design", "Product", "Legal"]
roles = ["admin", "manager", "user", "moderator", "analyst", "developer", "designer", "lead"]
cities = ["New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "Philadelphia", "San Antonio", "San Diego", "Dallas", "San Jose"]
states = ["NY", "CA", "IL", "TX", "AZ", "PA", "TX", "CA", "TX", "CA"]
categories = ["Technology", "Business", "Lifestyle", "Travel", "Food", "Health", "Sports", "Entertainment", "Science", "Education"]

# Insert 150 users
150.times do |i|
  name = "#{first_names.sample} #{last_names.sample}"
  email = "user#{i+1}@example.com"
  phone = "(#{rand(200..999)}) #{rand(200..999)}-#{rand(1000..9999)}"
  department = departments.sample
  role = roles.sample
  salary = rand(40000..150000).round(-3)
  address = "#{rand(100..9999)} #{['Main', 'Oak', 'Pine', 'Elm', 'Maple'].sample} St"
  city = cities.sample
  state = states.sample
  zip_code = rand(10000..99999).to_s
  active = [1, 1, 1, 1, 0].sample # 80% active
  last_login = Time.now - rand(0..90).days - rand(0..23).hours
  created = Time.now - rand(90..365).days
  
  sql = <<~SQL
    INSERT INTO users (name, email, phone, department, role, salary, address, city, state, zip_code, active, last_login_at, created_at, updated_at)
    VALUES ('#{name}', '#{email}', '#{phone}', '#{department}', '#{role}', #{salary}, '#{address}', '#{city}', '#{state}', '#{zip_code}', #{active}, '#{last_login.strftime('%Y-%m-%d %H:%M:%S')}', '#{created.strftime('%Y-%m-%d %H:%M:%S')}', '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}')
  SQL
  
  ActiveRecord::Base.connection.execute(sql)
end

# Insert 300 posts
300.times do |i|
  user_id = rand(1..150)
  title = "#{['How to', 'Guide to', 'Understanding', 'Introduction to', 'Deep Dive into', 'Tips for'].sample} #{['Success', 'Growth', 'Innovation', 'Excellence', 'Performance', 'Strategy'].sample}"
  content = "This is a sample blog post content with #{rand(100..1000)} words..."
  category = categories.sample
  tags = categories.sample(rand(2..4)).join(", ")
  view_count = rand(0..10000)
  like_count = rand(0..500)
  published = [0, 1, 1, 1].sample # 75% published
  published_at = published == 1 ? (Time.now - rand(0..180).days).strftime('%Y-%m-%d %H:%M:%S') : nil
  created = Time.now - rand(0..365).days
  
  sql = <<~SQL
    INSERT INTO posts (user_id, title, content, category, tags, view_count, like_count, published, published_at, created_at, updated_at)
    VALUES (#{user_id}, '#{title}', '#{content}', '#{category}', '#{tags}', #{view_count}, #{like_count}, #{published}, #{published_at ? "'#{published_at}'" : 'NULL'}, '#{created.strftime('%Y-%m-%d %H:%M:%S')}', '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}')
  SQL
  
  ActiveRecord::Base.connection.execute(sql)
end

puts "✅ Created 150 users and 300 posts for testing"
puts ""
puts "📊 Database Stats:"
puts "  Users table: 15 columns, 150 rows"
puts "  Posts table: 12 columns, 300 rows"
puts ""
puts "Sample queries to try:"
puts "  SELECT * FROM users LIMIT 20;"
puts "  SELECT * FROM users WHERE active = 1 AND salary > 100000;"
puts "  SELECT department, COUNT(*) as count FROM users GROUP BY department;"
puts "  SELECT name, email, role, salary FROM users WHERE department = 'Engineering' ORDER BY salary DESC;"
puts "  SELECT u.name, COUNT(p.id) as post_count FROM users u LEFT JOIN posts p ON u.id = p.user_id GROUP BY u.id ORDER BY post_count DESC LIMIT 10;"
puts "  SELECT category, AVG(view_count) as avg_views FROM posts WHERE published = 1 GROUP BY category;"
puts "  WITH active_users AS (SELECT * FROM users WHERE active = 1) SELECT department, COUNT(*) FROM active_users GROUP BY department;"
puts ""
puts "Sample queries to try:"
puts "  SELECT * FROM users;"
puts "  SELECT * FROM users WHERE active = 1;"
puts "  SELECT name, email, role FROM users ORDER BY name;"
puts "  SELECT u.name, COUNT(p.id) as post_count FROM users u LEFT JOIN posts p ON u.id = p.user_id GROUP BY u.id;"
puts "  WITH active_users AS (SELECT * FROM users WHERE active = 1) SELECT * FROM active_users;"
