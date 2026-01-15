# Test Queries for UI Scalability

The test database now contains **105 users** with **15 columns** each to test UI performance and layout.

## Database Schema

**Users table columns:**
1. id
2. name
3. email
4. role
5. active
6. created_at
7. phone
8. address
9. city
10. country
11. postal_code
12. department
13. salary
14. hire_date
15. notes

## Test Queries

### Test 1: Many Rows, All Columns
```sql
SELECT * FROM users;
```
**Expected:** 100 rows displayed (with truncation warning), 15 columns, horizontal scroll needed

### Test 2: Many Rows, Many Columns
```sql
SELECT * FROM users WHERE active = 1;
```
**Expected:** ~84 rows (80% are active), all 15 columns, horizontal scroll

### Test 3: Many Rows, Selected Columns
```sql
SELECT id, name, email, department, salary, city, country 
FROM users 
ORDER BY salary DESC;
```
**Expected:** 100 rows, 7 columns, fits better on screen

### Test 4: Narrow Result Set
```sql
SELECT id, name, email FROM users LIMIT 10;
```
**Expected:** 10 rows, 3 columns, no scrolling needed

### Test 5: Wide Table Test
```sql
SELECT name, email, phone, address, city, country, postal_code, 
       department, salary, hire_date, notes 
FROM users 
LIMIT 20;
```
**Expected:** 20 rows, 11 columns, requires horizontal scroll

### Test 6: Department Summary
```sql
SELECT department, 
       COUNT(*) as employee_count,
       ROUND(AVG(salary), 2) as avg_salary,
       MIN(salary) as min_salary,
       MAX(salary) as max_salary
FROM users 
WHERE active = 1
GROUP BY department
ORDER BY avg_salary DESC;
```
**Expected:** ~10 rows, 5 columns, aggregated data

### Test 7: Salary Analysis
```sql
SELECT 
  CASE 
    WHEN salary < 60000 THEN 'Junior'
    WHEN salary < 80000 THEN 'Mid-Level'
    WHEN salary < 100000 THEN 'Senior'
    ELSE 'Executive'
  END as level,
  COUNT(*) as count,
  department
FROM users
WHERE active = 1
GROUP BY level, department
ORDER BY level, department;
```
**Expected:** Multiple rows showing salary distribution

### Test 8: Geographic Distribution
```sql
SELECT country, city, COUNT(*) as employees, 
       ROUND(AVG(salary), 0) as avg_salary
FROM users
GROUP BY country, city
ORDER BY employees DESC;
```
**Expected:** ~10 rows showing geographic breakdown

### Test 9: Recent Hires
```sql
SELECT name, department, hire_date, salary
FROM users
WHERE hire_date > '2023-01-01'
ORDER BY hire_date DESC;
```
**Expected:** Recent hires ordered by date

### Test 10: Full Text Search
```sql
SELECT id, name, email, department, notes
FROM users
WHERE notes LIKE '%performance%' OR notes LIKE '%leadership%'
LIMIT 20;
```
**Expected:** Filtered results with matching text

## UI Features to Observe

1. **Horizontal Scrolling**: Wide tables should have smooth horizontal scroll
2. **Row Limiting**: Queries without LIMIT should show max 100 rows with warning
3. **Performance**: All queries should complete in < 1 second
4. **Truncation Warning**: Should show when results are limited
5. **Column Headers**: Should stay readable even with many columns
6. **NULL Handling**: Should display "NULL" in italic gray for null values
7. **Responsive Design**: Should work on different screen sizes
8. **Query History**: Queries should save to localStorage (max 20)
9. **Execution Time**: Should display milliseconds
10. **Row Count**: Should show accurate row count

## Expected Behaviors

### Good Performance
- ✅ Queries execute in < 500ms
- ✅ UI remains responsive during query
- ✅ Results render quickly
- ✅ Scrolling is smooth

### Proper Layout
- ✅ Tables don't break page layout
- ✅ Long text truncates or wraps appropriately
- ✅ Column headers are visible
- ✅ Horizontal scroll appears when needed

### Data Display
- ✅ Numbers formatted properly
- ✅ Dates display correctly
- ✅ NULL values show as "NULL"
- ✅ Text content is readable

## Stress Tests

### Maximum Rows Test
```sql
SELECT * FROM users;
-- Should limit to 100 rows automatically
```

### Maximum Columns Test  
```sql
SELECT * FROM users LIMIT 10;
-- Should show all 15 columns with horizontal scroll
```

### Combined Stress Test
```sql
SELECT * FROM users WHERE active = 1;
-- 84 rows × 15 columns = 1,260 cells
-- Should handle gracefully
```

## Current Configuration

- **Max Rows:** 100 (configured in initializer)
- **Timeout:** 30 seconds
- **History:** 20 queries (localStorage)
- **Database:** 105 users, 6 posts
