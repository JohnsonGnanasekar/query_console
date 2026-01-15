#!/usr/bin/env ruby
require 'date'

departments = ["Engineering", "Sales", "Marketing", "Support", "HR", "Finance", "Operations", "Product", "Design", "Legal"]
cities = [
  ["New York", "USA", "10001"],
  ["Los Angeles", "USA", "90001"],
  ["London", "UK", "SW1A"],
  ["Tokyo", "Japan", "100-0001"],
  ["Paris", "France", "75001"],
  ["Berlin", "Germany", "10115"],
  ["Sydney", "Australia", "2000"],
  ["Toronto", "Canada", "M5H"],
  ["Singapore", "Singapore", "018956"],
  ["Mumbai", "India", "400001"]
]

first_names = %w[James Mary John Patricia Robert Jennifer Michael Linda William Elizabeth David Barbara Richard Susan Joseph Jessica Thomas Sarah Charles Karen Daniel Nancy Matthew Betty Mark Sandra]
last_names = %w[Smith Johnson Williams Brown Jones Garcia Miller Davis Rodriguez Martinez Hernandez Lopez Gonzalez Wilson Anderson Thomas Taylor Moore Jackson Martin Lee White Harris Thompson]

roles = ["user", "user", "user", "user", "moderator", "admin"]
streets = %w[Main Oak Elm Pine Maple Cedar Birch Willow Cherry Ash]
street_types = %w[St Ave Blvd Dr Ln Rd Way Pl Ct]
notes_templates = [
  "Excellent performance and team collaboration",
  "Meets all expectations consistently",
  "Outstanding contributor to projects",
  "Strong team player with leadership potential",
  "Dedicated professional with great attitude",
  "Innovative thinker and problem solver",
  "Reliable and detail-oriented employee",
  "High performer with technical expertise"
]

File.open("spec/dummy/db/insert_users.sql", "w") do |f|
  100.times do |i|
    id = i + 6
    first = first_names.sample
    last = last_names.sample
    name = "#{first} #{last}"
    email = "#{first.downcase}.#{last.downcase}#{i}@company.com"
    role = roles.sample
    active = [1, 1, 1, 1, 0].sample
    phone = "+1-555-#{(1000 + i).to_s.rjust(4, '0')}"
    
    city_data = cities.sample
    city = city_data[0]
    country = city_data[1]
    postal = city_data[2]
    
    address = "#{100 + rand(900)} #{streets.sample} #{street_types.sample}"
    dept = departments.sample
    salary = (50000 + rand(100) * 1000).to_i
    
    days_ago = rand(1825)
    hire_date = (Date.today - days_ago).to_s
    
    notes = notes_templates.sample + ". #{dept} department member since #{hire_date.split('-')[0]}."
    
    # Escape single quotes in data
    name = name.gsub("'", "''")
    address = address.gsub("'", "''")
    notes = notes.gsub("'", "''")
    
    f.puts <<~SQL
      INSERT INTO users (id, name, email, role, active, phone, address, city, country, postal_code, department, salary, hire_date, notes)
      VALUES (#{id}, '#{name}', '#{email}', '#{role}', #{active}, '#{phone}', '#{address}', '#{city}', '#{country}', '#{postal}', '#{dept}', #{salary}, '#{hire_date}', '#{notes}');
    SQL
  end
end

puts "Generated insert_users.sql with 100 users"
