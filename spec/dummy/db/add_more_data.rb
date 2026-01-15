#!/usr/bin/env ruby

# Add more columns and data to test UI scalability

# Add more columns to users table
ActiveRecord::Base.connection.execute(<<~SQL)
  ALTER TABLE users ADD COLUMN phone TEXT;
SQL

ActiveRecord::Base.connection.execute(<<~SQL)
  ALTER TABLE users ADD COLUMN address TEXT;
SQL

ActiveRecord::Base.connection.execute(<<~SQL)
  ALTER TABLE users ADD COLUMN city TEXT;
SQL

ActiveRecord::Base.connection.execute(<<~SQL)
  ALTER TABLE users ADD COLUMN country TEXT;
SQL

ActiveRecord::Base.connection.execute(<<~SQL)
  ALTER TABLE users ADD COLUMN postal_code TEXT;
SQL

ActiveRecord::Base.connection.execute(<<~SQL)
  ALTER TABLE users ADD COLUMN department TEXT;
SQL

ActiveRecord::Base.connection.execute(<<~SQL)
  ALTER TABLE users ADD COLUMN salary REAL;
SQL

ActiveRecord::Base.connection.execute(<<~SQL)
  ALTER TABLE users ADD COLUMN hire_date TEXT;
SQL

ActiveRecord::Base.connection.execute(<<~SQL)
  ALTER TABLE users ADD COLUMN notes TEXT;
SQL

puts "✅ Added 9 new columns to users table"

# Update existing users with new data
existing_users = [
  [1, "+1-555-0101", "123 Admin St", "New York", "USA", "10001", "Management", 120000, "2020-01-15", "Senior administrator with full system access"],
  [2, "+1-555-0102", "456 User Ave", "Los Angeles", "USA", "90001", "Sales", 75000, "2021-03-20", "Sales representative handling enterprise accounts"],
  [3, "+1-555-0103", "789 Main Blvd", "Chicago", "USA", "60601", "Engineering", 95000, "2021-06-10", "Full-stack developer working on core features"],
  [4, "+1-555-0104", "321 Hero Lane", "Seattle", "USA", "98101", "Support", 65000, "2022-02-14", "Customer support specialist and community moderator"],
  [5, "+1-555-0105", "654 Inactive Rd", "Boston", "USA", "02101", "Marketing", 70000, "2019-11-30", "Former marketing coordinator, account currently inactive"]
]

existing_users.each do |id, phone, address, city, country, postal, dept, salary, hire, notes|
  ActiveRecord::Base.connection.execute(<<~SQL)
    UPDATE users 
    SET phone = '#{phone}',
        address = '#{address}',
        city = '#{city}',
        country = '#{country}',
        postal_code = '#{postal}',
        department = '#{dept}',
        salary = #{salary},
        hire_date = '#{hire}',
        notes = '#{notes}'
    WHERE id = #{id}
  SQL
end

puts "✅ Updated existing 5 users with detailed information"

# Generate many more users
departments = ["Engineering", "Sales", "Marketing", "Support", "HR", "Finance", "Operations", "Product", "Design", "Legal"]
cities = [
  ["New York", "USA", "10001"],
  ["Los Angeles", "USA", "90001"],
  ["London", "UK", "SW1A 1AA"],
  ["Tokyo", "Japan", "100-0001"],
  ["Paris", "France", "75001"],
  ["Berlin", "Germany", "10115"],
  ["Sydney", "Australia", "2000"],
  ["Toronto", "Canada", "M5H 2N2"],
  ["Singapore", "Singapore", "018956"],
  ["Mumbai", "India", "400001"]
]

first_names = %w[James Mary John Patricia Robert Jennifer Michael Linda William Elizabeth David Barbara Richard Susan Joseph Jessica Thomas Sarah Charles Karen]
last_names = %w[Smith Johnson Williams Brown Jones Garcia Miller Davis Rodriguez Martinez Hernandez Lopez Gonzalez Wilson Anderson Thomas Taylor Moore Jackson Martin]

roles = ["user", "user", "user", "user", "moderator", "admin"]

100.times do |i|
  id = i + 6
  first = first_names.sample
  last = last_names.sample
  name = "#{first} #{last}"
  email = "#{first.downcase}.#{last.downcase}#{i}@example.com"
  role = roles.sample
  active = [1, 1, 1, 1, 0].sample # 80% active
  phone = "+1-555-#{(1000 + i).to_s.rjust(4, '0')}"
  
  city_data = cities.sample
  city = city_data[0]
  country = city_data[1]
  postal = city_data[2]
  
  address = "#{100 + i} #{['Main', 'Oak', 'Elm', 'Pine', 'Maple', 'Cedar'].sample} #{['St', 'Ave', 'Blvd', 'Dr', 'Ln'].sample}"
  dept = departments.sample
  salary = (50000 + rand(100000)).round(-3)
  
  # Random hire date in last 5 years
  days_ago = rand(1825)
  hire_date = (Date.today - days_ago).to_s
  
  notes = "Employee #{id} in #{dept} department. #{['Excellent performance', 'Meets expectations', 'Outstanding contributor', 'Team player', 'Leadership potential'].sample}."
  
  sql = <<~SQL
    INSERT INTO users (id, name, email, role, active, phone, address, city, country, postal_code, department, salary, hire_date, notes)
    VALUES (#{id}, '#{name}', '#{email}', '#{role}', #{active}, '#{phone}', '#{address}', '#{city}', '#{country}', '#{postal}', '#{dept}', #{salary}, '#{hire_date}', '#{notes}')
  SQL
  
  ActiveRecord::Base.connection.execute(sql)
  
  print "\rGenerated #{i + 1}/100 users..." if (i + 1) % 10 == 0
end

puts "\n✅ Generated 100 additional users"
puts "\n📊 Database now contains:"
puts "   - #{ActiveRecord::Base.connection.execute('SELECT COUNT(*) FROM users').first['COUNT(*)']} total users"
puts "   - 14 columns per user (id, name, email, role, active, created_at, phone, address, city, country, postal_code, department, salary, hire_date, notes)"
puts "\n🎯 Test queries:"
puts "   SELECT * FROM users;                                    -- All columns, all rows"
puts "   SELECT * FROM users LIMIT 10;                           -- First 10 rows"
puts "   SELECT id, name, email, department, salary FROM users;  -- Selected columns"
puts "   SELECT * FROM users WHERE active = 1 ORDER BY salary DESC; -- Filtered and sorted"
