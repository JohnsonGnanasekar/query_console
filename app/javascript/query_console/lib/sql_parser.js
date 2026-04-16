/**
 * Enhanced SQL parser for extracting table names from SQL queries
 * Used by autocomplete to provide context-aware suggestions
 */

/**
 * Extract table names from SQL query text
 * Supports: SELECT, UPDATE, INSERT, DELETE, FROM, JOIN clauses
 * 
 * @param {string} sql - SQL query text
 * @returns {Array<string>} Array of table names (lowercase, deduplicated)
 */
export function getTablesFromQuery(sql) {
  if (!sql || typeof sql !== 'string') {
    return [];
  }

  const tables = [];
  const sqlUpper = sql.toUpperCase();
  
  // Enhanced regex to exclude parentheses and other SQL noise
  // Matches: word characters, dots (for schema.table), underscores
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

/**
 * Check if cursor is in SET clause of UPDATE statement
 * 
 * @param {string} textBeforeCursor - SQL text before cursor position
 * @returns {boolean} True if in SET clause
 */
export function isInSetClause(textBeforeCursor) {
  return /\bUPDATE\s+\w+\s+SET\s/i.test(textBeforeCursor);
}

/**
 * Check if cursor is in column list of INSERT statement
 * 
 * @param {string} textBeforeCursor - SQL text before cursor position
 * @returns {boolean} True if in INSERT column list
 */
export function isInInsertColumns(textBeforeCursor) {
  const inInsert = /\bINSERT\s+INTO\s+\w+\s*\(/i.test(textBeforeCursor);
  const hasValues = textBeforeCursor.toUpperCase().includes('VALUES');
  return inInsert && !hasValues;
}

/**
 * Normalize table name for comparison
 * Handles schema-qualified names by returning just the table part
 * 
 * @param {string} tableName - Table name (may include schema)
 * @returns {string} Normalized table name
 */
export function normalizeTableName(tableName) {
  if (!tableName) return '';
  
  // If schema-qualified (e.g., "public.users"), return just table name
  if (tableName.includes('.')) {
    const parts = tableName.split('.');
    return parts[parts.length - 1].toLowerCase();
  }
  
  return tableName.toLowerCase();
}
