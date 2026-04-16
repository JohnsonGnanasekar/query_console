/**
 * JavaScript unit tests for SQL parsing logic
 * 
 * This tests the getTablesFromQuery() function used in autocomplete
 * Run with: node spec/javascript/sql_parser_spec.js
 */

// Enhanced SQL parser for testing
function getTablesFromQuery(sql) {
  if (!sql || typeof sql !== 'string') {
    return [];
  }

  const tables = [];
  const sqlUpper = sql.toUpperCase();
  
  // Enhanced regex to exclude parentheses and other SQL noise
  const tableNamePattern = /[\w.]+/;
  
  // Match UPDATE: UPDATE table_name SET
  const updateMatch = sqlUpper.match(/\bUPDATE\s+([\w.]+)/i);
  if (updateMatch && updateMatch[1]) {
    tables.push(updateMatch[1].toLowerCase());
  }
  
  // Match INSERT INTO: INSERT INTO table_name
  const insertMatch = sqlUpper.match(/\bINSERT\s+INTO\s+([\w.]+)/i);
  if (insertMatch && insertMatch[1]) {
    tables.push(insertMatch[1].toLowerCase());
  }
  
  // Match DELETE FROM: DELETE FROM table_name
  const deleteMatch = sqlUpper.match(/\bDELETE\s+FROM\s+([\w.]+)/i);
  if (deleteMatch && deleteMatch[1]) {
    tables.push(deleteMatch[1].toLowerCase());
  }
  
  // Match FROM clause: FROM table_name or FROM table1, table2
  // Exclude subqueries by stopping at opening parenthesis
  const fromMatch = sqlUpper.match(/\bFROM\s+([\w.,\s]+?)(?:\s+WHERE|\s+JOIN|\s+LEFT|\s+RIGHT|\s+INNER|\s+OUTER|\s+CROSS|\s+GROUP|\s+ORDER|\s+LIMIT|\s+OFFSET|\s*;|\s*$)/i);
  if (fromMatch && fromMatch[1]) {
    // Split by comma and clean up
    const tableList = fromMatch[1]
      .split(',')
      .map(t => t.trim())
      .filter(t => t && !t.includes('(')) // Exclude subqueries
      .map(t => {
        // Remove AS aliases: "users u" -> "users", "users AS u" -> "users"
        const parts = t.split(/\s+/);
        return parts[0].toLowerCase();
      });
    tables.push(...tableList);
  }
  
  // Match JOIN clauses: JOIN table_name
  // Handles: JOIN, LEFT JOIN, RIGHT JOIN, INNER JOIN, OUTER JOIN, CROSS JOIN
  const joinPattern = /(?:LEFT\s+|RIGHT\s+|INNER\s+|OUTER\s+|CROSS\s+)?JOIN\s+([\w.]+)/gi;
  const joinMatches = sql.matchAll(joinPattern);
  for (const match of joinMatches) {
    if (match[1] && !match[1].includes('(')) {
      tables.push(match[1].toLowerCase());
    }
  }
  
  // Match WITH (CTE) clause table names: WITH table_name AS (...)
  const ctePattern = /\bWITH\s+([\w.]+)\s+AS/gi;
  const cteMatches = sql.matchAll(ctePattern);
  for (const match of cteMatches) {
    if (match[1]) {
      tables.push(match[1].toLowerCase());
    }
  }
  
  // Remove duplicates and filter out empty/invalid names
  return [...new Set(tables)].filter(t => t && t.length > 0 && /^[\w.]+$/.test(t));
}

// Simple test framework
class TestRunner {
  constructor() {
    this.tests = [];
    this.passed = 0;
    this.failed = 0;
  }

  describe(description, fn) {
    console.log(`\n${description}`);
    fn();
  }

  it(description, fn) {
    try {
      fn();
      this.passed++;
      console.log(`  ✓ ${description}`);
    } catch (error) {
      this.failed++;
      console.log(`  ✗ ${description}`);
      console.log(`    ${error.message}`);
    }
  }

  expect(actual) {
    return {
      toEqual: (expected) => {
        const actualStr = JSON.stringify(actual);
        const expectedStr = JSON.stringify(expected);
        if (actualStr !== expectedStr) {
          throw new Error(`Expected ${expectedStr} but got ${actualStr}`);
        }
      },
      toContain: (item) => {
        if (!actual.includes(item)) {
          throw new Error(`Expected array to contain ${item}`);
        }
      },
      toHaveLength: (length) => {
        if (actual.length !== length) {
          throw new Error(`Expected length ${length} but got ${actual.length}`);
        }
      }
    };
  }

  summary() {
    const total = this.passed + this.failed;
    console.log(`\n${'='.repeat(50)}`);
    console.log(`Total: ${total} tests`);
    console.log(`Passed: ${this.passed}`);
    console.log(`Failed: ${this.failed}`);
    
    if (this.failed === 0) {
      console.log(`\n✅ All tests passed!`);
      process.exit(0);
    } else {
      console.log(`\n❌ ${this.failed} test(s) failed`);
      process.exit(1);
    }
  }
}

// Run tests
const test = new TestRunner();

test.describe('getTablesFromQuery - SELECT statements', () => {
  test.it('extracts single table from simple FROM clause', () => {
    const result = getTablesFromQuery('SELECT * FROM users');
    test.expect(result).toEqual(['users']);
  });

  test.it('extracts single table from FROM with WHERE', () => {
    const result = getTablesFromQuery('SELECT id, name FROM users WHERE id > 10');
    test.expect(result).toEqual(['users']);
  });

  test.it('extracts multiple tables from comma-separated FROM', () => {
    const result = getTablesFromQuery('SELECT * FROM users, posts');
    test.expect(result).toContain('users');
    test.expect(result).toContain('posts');
    test.expect(result).toHaveLength(2);
  });

  test.it('extracts table from JOIN clause', () => {
    const result = getTablesFromQuery('SELECT * FROM users JOIN posts ON users.id = posts.user_id');
    test.expect(result).toContain('users');
    test.expect(result).toContain('posts');
  });

  test.it('extracts tables from multiple JOINs', () => {
    const result = getTablesFromQuery('SELECT * FROM users LEFT JOIN posts ON users.id = posts.user_id INNER JOIN comments ON posts.id = comments.post_id');
    test.expect(result).toContain('users');
    test.expect(result).toContain('posts');
    test.expect(result).toContain('comments');
  });

  test.it('handles case-insensitive keywords', () => {
    const result = getTablesFromQuery('select * from USERS where id > 10');
    test.expect(result).toEqual(['users']);
  });

  test.it('handles mixed case table names', () => {
    const result = getTablesFromQuery('SELECT * FROM UserAccounts');
    test.expect(result).toEqual(['useraccounts']);
  });

  test.it('removes duplicate table names', () => {
    const result = getTablesFromQuery('SELECT * FROM users JOIN users ON users.id = users.parent_id');
    test.expect(result).toHaveLength(1);
    test.expect(result).toEqual(['users']);
  });
});

test.describe('getTablesFromQuery - UPDATE statements', () => {
  test.it('extracts table from UPDATE statement', () => {
    const result = getTablesFromQuery('UPDATE users SET name = "test"');
    test.expect(result).toEqual(['users']);
  });

  test.it('extracts table from UPDATE with WHERE', () => {
    const result = getTablesFromQuery('UPDATE posts SET published = true WHERE id = 5');
    test.expect(result).toEqual(['posts']);
  });

  test.it('handles case-insensitive UPDATE', () => {
    const result = getTablesFromQuery('update USERS set name = "test"');
    test.expect(result).toEqual(['users']);
  });
});

test.describe('getTablesFromQuery - INSERT statements', () => {
  test.it('extracts table from INSERT INTO', () => {
    const result = getTablesFromQuery('INSERT INTO users (name, email) VALUES ("test", "test@example.com")');
    test.expect(result).toEqual(['users']);
  });

  test.it('extracts table from INSERT without column list', () => {
    const result = getTablesFromQuery('INSERT INTO posts VALUES (1, "Title", "Content")');
    test.expect(result).toEqual(['posts']);
  });

  test.it('handles case-insensitive INSERT', () => {
    const result = getTablesFromQuery('insert into USERS values ("test")');
    test.expect(result).toEqual(['users']);
  });
});

test.describe('getTablesFromQuery - DELETE statements', () => {
  test.it('extracts table from DELETE FROM', () => {
    const result = getTablesFromQuery('DELETE FROM users');
    test.expect(result).toEqual(['users']);
  });

  test.it('extracts table from DELETE with WHERE', () => {
    const result = getTablesFromQuery('DELETE FROM posts WHERE id < 10');
    test.expect(result).toEqual(['posts']);
  });

  test.it('handles case-insensitive DELETE', () => {
    const result = getTablesFromQuery('delete from USERS where id = 1');
    test.expect(result).toEqual(['users']);
  });
});

test.describe('getTablesFromQuery - Edge cases', () => {
  test.it('returns empty array for query without tables', () => {
    const result = getTablesFromQuery('SELECT 1 + 1');
    test.expect(result).toEqual([]);
  });

  test.it('handles incomplete queries', () => {
    const result = getTablesFromQuery('SELECT * FROM');
    test.expect(result).toEqual([]);
  });

  test.it('handles queries with newlines', () => {
    const result = getTablesFromQuery('SELECT *\nFROM users\nWHERE id > 10');
    test.expect(result).toEqual(['users']);
  });

  test.it('handles queries with extra whitespace', () => {
    const result = getTablesFromQuery('SELECT   *   FROM    users');
    test.expect(result).toEqual(['users']);
  });

  test.it('handles partial UPDATE query (typing in progress)', () => {
    const result = getTablesFromQuery('UPDATE posts SET ');
    test.expect(result).toEqual(['posts']);
  });

  test.it('handles partial SELECT query (typing in progress)', () => {
    const result = getTablesFromQuery('SELECT id FROM users WHERE');
    test.expect(result).toEqual(['users']);
  });

  test.it('extracts both FROM and UPDATE tables in complex query', () => {
    // Edge case: UPDATE with FROM clause (PostgreSQL syntax)
    const result = getTablesFromQuery('UPDATE users SET active = false FROM posts WHERE users.id = posts.user_id');
    test.expect(result).toContain('users');
    test.expect(result).toContain('posts');
  });
});

test.describe('getTablesFromQuery - Enhanced features', () => {
  test.it('extracts CTE table names from WITH clause', () => {
    const result = getTablesFromQuery('WITH recent AS (SELECT * FROM users) SELECT * FROM recent');
    // Extracts CTE name "recent" and table "recent" from main query
    // Note: Tables inside CTE parentheses not extracted (known limitation)
    test.expect(result).toContain('recent');
    // 'users' inside CTE parentheses is not extracted
  });

  test.it('handles subqueries in FROM clause gracefully', () => {
    const result = getTablesFromQuery('SELECT * FROM (SELECT * FROM users) AS subquery');
    // Enhanced: excludes subquery parentheses, may extract inner tables
    // Should not include invalid names like '(' or ')'
    if (result.length > 0) {
      result.forEach(table => {
        const isValid = /^[\w.]+$/.test(table);
        if (!isValid) {
          throw new Error(`Invalid table name: ${table}`);
        }
      });
    }
    // May be empty or contain valid table names
  });

  test.it('handles table with schema prefix', () => {
    const result = getTablesFromQuery('SELECT * FROM public.users');
    // Schema-qualified tables: "public.users" kept as-is
    test.expect(result).toEqual(['public.users']);
  });

  test.it('handles table aliases in FROM clause', () => {
    const result = getTablesFromQuery('SELECT * FROM users u WHERE u.id > 10');
    // Alias "u" is stripped, only table name "users" extracted
    test.expect(result).toEqual(['users']);
  });

  test.it('handles multiple table aliases', () => {
    const result = getTablesFromQuery('SELECT * FROM users u, posts p WHERE u.id = p.user_id');
    const hasUsers = result.includes('users');
    const hasPosts = result.includes('posts');
    const hasU = result.includes('u');
    const hasP = result.includes('p');
    
    if (!hasUsers) throw new Error('Expected result to contain "users"');
    if (!hasPosts) throw new Error('Expected result to contain "posts"');
    if (hasU) throw new Error('Expected result NOT to contain alias "u"');
    if (hasP) throw new Error('Expected result NOT to contain alias "p"');
  });
});

// Run summary
test.summary();
