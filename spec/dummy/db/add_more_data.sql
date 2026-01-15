-- Add more columns to users table
ALTER TABLE users ADD COLUMN phone TEXT;
ALTER TABLE users ADD COLUMN address TEXT;
ALTER TABLE users ADD COLUMN city TEXT;
ALTER TABLE users ADD COLUMN country TEXT;
ALTER TABLE users ADD COLUMN postal_code TEXT;
ALTER TABLE users ADD COLUMN department TEXT;
ALTER TABLE users ADD COLUMN salary REAL;
ALTER TABLE users ADD COLUMN hire_date TEXT;
ALTER TABLE users ADD COLUMN notes TEXT;

-- Update existing users with detailed data
UPDATE users SET 
  phone = '+1-555-0101',
  address = '123 Admin St',
  city = 'New York',
  country = 'USA',
  postal_code = '10001',
  department = 'Management',
  salary = 120000,
  hire_date = '2020-01-15',
  notes = 'Senior administrator with full system access'
WHERE id = 1;

UPDATE users SET 
  phone = '+1-555-0102',
  address = '456 User Ave',
  city = 'Los Angeles',
  country = 'USA',
  postal_code = '90001',
  department = 'Sales',
  salary = 75000,
  hire_date = '2021-03-20',
  notes = 'Sales representative handling enterprise accounts'
WHERE id = 2;

UPDATE users SET 
  phone = '+1-555-0103',
  address = '789 Main Blvd',
  city = 'Chicago',
  country = 'USA',
  postal_code = '60601',
  department = 'Engineering',
  salary = 95000,
  hire_date = '2021-06-10',
  notes = 'Full-stack developer working on core features'
WHERE id = 3;

UPDATE users SET 
  phone = '+1-555-0104',
  address = '321 Hero Lane',
  city = 'Seattle',
  country = 'USA',
  postal_code = '98101',
  department = 'Support',
  salary = 65000,
  hire_date = '2022-02-14',
  notes = 'Customer support specialist and community moderator'
WHERE id = 4;

UPDATE users SET 
  phone = '+1-555-0105',
  address = '654 Inactive Rd',
  city = 'Boston',
  country = 'USA',
  postal_code = '02101',
  department = 'Marketing',
  salary = 70000,
  hire_date = '2019-11-30',
  notes = 'Former marketing coordinator, account currently inactive'
WHERE id = 5;
