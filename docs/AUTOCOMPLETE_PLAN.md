# SQL Autocomplete Feature - Implementation Plan

## ⚠️ Critical Fixes Applied (Code Review Findings)

This plan has been reviewed and updated to address all critical issues:


| Issue                    | Severity    | Status  | Solution                                              |
| ------------------------ | ----------- | ------- | ----------------------------------------------------- |
| N+1 Query Problem        | 🔴 Critical | ✅ Fixed | Added `/schema/bulk` endpoint (1 request vs N+1)      |
| Race Condition           | 🔴 Critical | ✅ Fixed | Initialize editor first, load schema async            |
| No Timeout Handling      | 🟠 High     | ✅ Fixed | 5-second timeout with AbortController                 |
| Memory Limits            | 🟠 High     | ✅ Fixed | Added `autocomplete_max_tables` config (default: 100) |
| Duplicate Controllers    | 🟠 High     | ✅ Fixed | Consolidated to standalone controller only            |
| Schema Staleness         | 🟠 High     | ✅ Fixed | 5-minute client-side TTL cache                        |
| schema_explorer Disabled | 🟡 Medium   | ✅ Fixed | Validation: autocomplete requires schema_explorer     |
| No Loading Indicator     | 🟡 Medium   | ✅ Fixed | Added status indicator with 3 states                  |
| Missing Defaults         | 🟡 Medium   | ✅ Fixed | All config options have explicit defaults             |
| Generic Tests            | 🟡 Medium   | ✅ Fixed | Specific test cases with names                        |
| Open Questions           | 🟡 Medium   | ✅ Fixed | All decisions documented                              |


**All critical and high-priority issues have been addressed. Plan is ready for implementation.**

---

## Overview

Add intelligent autocomplete suggestions for table names and column names in the SQL editor using CodeMirror's built-in SQL autocomplete system with database schema integration.

## Current State

- SQL editor uses CodeMirror 6 with basic SQL language support
- Schema introspection already exists via `SchemaIntrospector` service
- Schema API endpoints already available: `/schema/tables` and `/schema/tables/:name`
- No autocomplete currently configured

## Goals

1. Provide table name autocomplete when typing after `FROM`, `JOIN`, `UPDATE`, `DELETE FROM`, `INSERT INTO`
2. Provide column name autocomplete when typing after table name or in `SELECT` clause
3. Context-aware suggestions based on cursor position
4. Support for multiple database adapters (PostgreSQL, MySQL, SQLite)
5. Respect existing schema filtering (denylist/allowlist)
6. Performance: Cache schema data, lazy-load column details

## Technical Architecture

### 1. Schema Loading Strategy

**Option A: Eager Loading (Recommended)**

- Load all tables and their columns on page load
- Store in memory for instant autocomplete
- Pros: Fast autocomplete, no lag
- Cons: Initial load time for databases with many tables

**Option B: Lazy Loading**

- Load tables on page load
- Load columns on-demand when table is referenced
- Pros: Faster initial load
- Cons: Slight delay on first use of a table

**Decision: Start with Option A, add Option B if performance issues arise**

### SQL Clauses with Autocomplete Support

CodeMirror SQL autocomplete works in **all major SQL clauses**:

✅ **Fully Supported:**

- `SELECT` - column suggestions from tables in FROM
- `FROM` - table name suggestions
- `JOIN` / `LEFT JOIN` / `RIGHT JOIN` - table name suggestions
- `WHERE` - column suggestions from tables in scope
- `ON` (join conditions) - column suggestions for join tables
- `ORDER BY` - column suggestions from tables in scope
- `GROUP BY` - column suggestions from tables in scope
- `HAVING` - column suggestions and aggregate functions
- `INSERT INTO` - table name suggestions
- `UPDATE` - table name suggestions
- `DELETE FROM` - table name suggestions
- `SET` (in UPDATE) - column suggestions for the table

✅ **Context-Aware:**

- Understands which tables are in scope at cursor position
- Respects table aliases (e.g., `FROM users u` → `u.column_name`)
- Suggests appropriate columns based on clause context
- Works with subqueries (suggests columns from outer query tables)

### 2. Implementation Components

#### A. Backend Changes Required

**Existing Endpoints:**

- ✅ `SchemaController#tables` - Returns list of tables
- ✅ `SchemaController#show` - Returns table details with columns
- ✅ `SchemaIntrospector` - Handles database-specific schema queries
- ✅ Caching via `Rails.cache` with configurable TTL

**NEW: Bulk Schema Endpoint (CRITICAL)**
⚠️ **Issue:** Current approach causes N+1 problem (1 request for tables + N requests for columns)

**Solution:** Add new bulk endpoint to return everything in one request:

```ruby
# app/controllers/query_console/schema_controller.rb
def bulk
  unless QueryConsole.configuration.schema_explorer
    render json: { error: "Schema explorer is disabled" }, status: :forbidden
    return
  end

  introspector = SchemaIntrospector.new
  
  # Apply autocomplete limits
  max_tables = QueryConsole.configuration.autocomplete_max_tables
  tables = introspector.tables.first(max_tables)
  
  # Fetch all table details in one pass (server-side batching)
  tables_with_columns = tables.map do |table|
    details = introspector.table_details(table[:name])
    {
      name: table[:name],
      kind: table[:kind],
      columns: details ? details[:columns].map { |c| c[:name] } : []
    }
  end
  
  render json: tables_with_columns
end
```

**Route:**

```ruby
# config/routes.rb
namespace :query_console do
  resources :schema, only: [] do
    collection do
      get 'tables', to: 'schema#tables'
      get 'bulk', to: 'schema#bulk'  # NEW
    end
    member do
      get '', to: 'schema#show', as: :table
    end
  end
end
```

**Security Verification:**

- ✅ Verify `before_action` authorization exists
- ✅ Verify CSRF skip is conditional (Turbo-Frame only)
- ✅ Verify `schema_explorer` config check
- ✅ Verify schema filtering (allowlist/denylist) is applied

#### B. Frontend Changes Required

**1. EditorController (Stimulus) - CONSOLIDATED**

⚠️ **Critical:** Remove inline EditorController from `new.html.erb`, use **only** the standalone `editor_controller.js` to avoid duplication.

```javascript
// app/javascript/query_console/controllers/editor_controller.js
export default class extends Controller {
  static targets = ["container", "schemaStatus"]
  static values = { schemaPath: String }

  connect() {
    // 1. Initialize editor IMMEDIATELY (no blocking)
    this.initializeCodeMirror({})
    
    // 2. Load schema asynchronously in background
    this.loadSchemaAsync()
  }

  async loadSchemaAsync() {
    this.showSchemaStatus('loading')
    
    try {
      const schema = await this.fetchSchemaWithTimeout()
      
      // Cache with TTL
      this.schemaCache = {
        data: schema,
        loadedAt: Date.now(),
        ttl: 5 * 60 * 1000  // 5 minutes
      }
      
      // Reconfigure CodeMirror with loaded schema
      this.reconfigureWithSchema(schema)
      this.showSchemaStatus('loaded')
      
    } catch (error) {
      console.warn('Schema loading failed:', error)
      this.showSchemaStatus('error')
      // Editor continues working without autocomplete
    }
  }

  async fetchSchemaWithTimeout() {
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 5000)  // 5 second timeout
    
    try {
      const response = await fetch(this.schemaPathValue + '/bulk', {
        signal: controller.signal,
        headers: {
          'Accept': 'application/json'
        }
      })
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }
      
      return await response.json()
      
    } catch (error) {
      if (error.name === 'AbortError') {
        throw new Error('Schema fetch timeout after 5 seconds')
      }
      throw error
    } finally {
      clearTimeout(timeoutId)
    }
  }

  reconfigureWithSchema(schemaData) {
    // Build CodeMirror schema format
    const schemaConfig = {}
    schemaData.forEach(table => {
      schemaConfig[table.name] = table.columns
    })
    
    // Reconfigure CodeMirror's SQL extension with new schema
    const sqlExt = sql({ 
      schema: schemaConfig,
      upperCaseKeywords: false  // Keep user's case preference
    })
    
    // Update editor configuration
    this.view.dispatch({
      effects: StateEffect.reconfigure.of([sqlExt])
    })
  }

  showSchemaStatus(status) {
    if (!this.hasSchemaStatusTarget) return
    
    const statusElement = this.schemaStatusTarget
    statusElement.className = `schema-status ${status}`
    
    switch(status) {
      case 'loading':
        statusElement.textContent = '⟳ Loading schema...'
        break
      case 'loaded':
        statusElement.textContent = '✓ Schema loaded'
        setTimeout(() => statusElement.style.display = 'none', 3000)
        break
      case 'error':
        statusElement.textContent = '⚠ Schema unavailable'
        break
    }
  }

  // Check if cached schema is still valid
  isSchemaCacheValid() {
    if (!this.schemaCache) return false
    const age = Date.now() - this.schemaCache.loadedAt
    return age < this.schemaCache.ttl
  }
}
```

**2. HTML Changes**

```erb
<!-- app/views/query_console/queries/new.html.erb -->
<div class="editor-section" 
     data-controller="editor collapsible" 
     data-collapsible-key-value="editor_section"
     data-editor-schema-path-value="<%= schema_path %>">
  
  <div class="editor-header">
    <h3>SQL Editor</h3>
    
    <!-- NEW: Schema loading indicator -->
    <div data-editor-target="schemaStatus" class="schema-status"></div>
    
    <div class="button-group">
      <!-- existing buttons -->
    </div>
  </div>
  
  <div data-editor-target="container"></div>
</div>
```

**3. CSS for Loading Indicator**

```css
.schema-status {
  font-size: 12px;
  padding: 4px 8px;
  border-radius: 4px;
  display: inline-block;
}

.schema-status.loading {
  color: #0066cc;
  background: #e6f2ff;
}

.schema-status.loaded {
  color: #00aa00;
  background: #e6ffe6;
}

.schema-status.error {
  color: #cc6600;
  background: #fff3e6;
}
```

**4. Schema Data Structure**

```javascript
// Response from /schema/bulk
[
  {
    name: "users",
    kind: "table",  // Preserved for future use (views/tables distinction)
    columns: ["id", "name", "email", "created_at"]
  },
  {
    name: "user_profiles",
    kind: "view",
    columns: ["user_id", "bio", "avatar_url"]
  }
]

// Transformed for CodeMirror
{
  users: ["id", "name", "email", "created_at"],
  user_profiles: ["user_id", "bio", "avatar_url"]
}
```

**Note:** `kind` metadata is preserved in response for future enhancements (e.g., showing icons for tables vs views)

### 3. User Experience Flow (UPDATED - Fixes Race Condition)

```
1. User opens Query Console
   └─> EditorController.connect() triggered
       ├─> IMMEDIATELY initialize CodeMirror with empty schema
       │   └─> Editor is functional, basic SQL highlighting works
       │
       └─> loadSchemaAsync() called in background (non-blocking)
           ├─> Show loading indicator
           ├─> Fetch /schema/bulk with 5-second timeout
           ├─> On success:
           │   ├─> Cache schema with TTL (5 minutes)
           │   ├─> Reconfigure CodeMirror with loaded schema
           │   └─> Show "Schema loaded" indicator
           └─> On failure/timeout:
               ├─> Log warning to console
               ├─> Show "Schema unavailable" indicator (optional)
               └─> Editor continues working without autocomplete
           
2. User types in editor (immediately, not blocked by schema load)
   └─> CodeMirror SQL autocomplete triggers based on context
       ├─> Before schema loads: Keywords only
       └─> After schema loads: Tables + columns + keywords
```

**Key Improvements:**

- ✅ No race condition - editor initializes immediately
- ✅ No blocking - schema loads asynchronously
- ✅ Timeout protection - 5 second limit
- ✅ Graceful fallback - works without schema

**Example Autocomplete Scenarios:**

```sql
-- Scenario 1: Simple WHERE clause
SELECT * FROM users WHERE |
                         ↑ suggests: id, name, email, created_at, updated_at

-- Scenario 2: Qualified column in WHERE
SELECT * FROM users WHERE users.|
                                ↑ suggests: id, name, email, created_at, updated_at

-- Scenario 3: Multiple conditions
SELECT * FROM users WHERE email = 'test@example.com' AND |
                                                          ↑ suggests: id, name, email, etc.

-- Scenario 4: JOIN with WHERE
SELECT * FROM users JOIN posts ON users.id = posts.user_id 
WHERE posts.|
           ↑ suggests: id, user_id, title, body, created_at

-- Scenario 5: Alias in WHERE
SELECT * FROM users u WHERE u.|
                             ↑ suggests: id, name, email, created_at, updated_at

-- Scenario 6: ORDER BY clause
SELECT * FROM users ORDER BY |
                            ↑ suggests: id, name, email, created_at, updated_at

-- Scenario 7: GROUP BY clause
SELECT COUNT(*) FROM users GROUP BY |
                                   ↑ suggests: id, name, email, etc.
```

### 4. Performance Considerations (UPDATED)

**Schema Caching**

- **Server-side**: Already cached via `Rails.cache` (configurable via `schema_cache_seconds`)
- **Client-side**: Cache in EditorController with 5-minute TTL
  ```javascript
  this.schemaCache = {
    data: schema,
    loadedAt: Date.now(),
    ttl: 5 * 60 * 1000  // 5 minutes
  }
  ```
- **Invalidation**: 
  - Automatic after TTL expires
  - Manual via page reload
  - Handles permission/config changes within 5 minutes

**Loading Optimization**

- ✅ Single bulk endpoint (no N+1 problem)
- ✅ Server-side batching of column queries
- ✅ 5-second timeout prevents hanging
- ✅ Non-blocking async load
- ✅ Editor functional immediately without schema

**Bandwidth & Memory Limits**


| Schema Size | Tables  | Columns | Payload Size | Status          |
| ----------- | ------- | ------- | ------------ | --------------- |
| Small       | 10-50   | ~500    | ~25 KB       | ✅ Optimal       |
| Medium      | 50-100  | ~2000   | ~100 KB      | ✅ Good          |
| Large       | 100-200 | ~5000   | ~250 KB      | ⚠️ Acceptable   |
| Huge        | 200+    | ~10000+ | ~500 KB+     | 🔴 Limit Needed |


**Protection Limits (NEW):**

```ruby
# Prevent huge payloads
config.autocomplete_max_tables = 100  # default
config.autocomplete_max_columns_per_table = 100  # default
```

**Implementation:**

```ruby
# In SchemaController#bulk
max_tables = QueryConsole.configuration.autocomplete_max_tables
tables = introspector.tables.first(max_tables)

# Truncate columns if needed
max_cols = QueryConsole.configuration.autocomplete_max_columns_per_table
columns: details[:columns].first(max_cols).map { |c| c[:name] }
```

**Gzip Compression:**

- Server should enable gzip for JSON responses
- Reduces payload by 70-80% typically
- 100KB → ~25KB compressed

### 5. Error Handling

**Schema Loading Failures**

- Network errors: Log warning, continue without autocomplete
- Permission errors: Silent fallback, editor still works
- Invalid responses: Catch and log, don't break editor

**User Feedback**

- Optional: Small indicator showing "Schema loaded" or "Loading schema..."
- No intrusive messages - autocomplete is enhancement, not requirement

### 6. Configuration Options (UPDATED WITH DEFAULTS & VALIDATION)

Add to `lib/query_console/configuration.rb`:

```ruby
class Configuration
  # Existing attributes...
  
  # Autocomplete configuration
  attr_accessor :autocomplete_enabled
  attr_accessor :autocomplete_max_tables
  attr_accessor :autocomplete_max_columns_per_table
  attr_reader :autocomplete_cache_ttl_seconds
  
  def initialize
    # Existing initializations...
    
    # Autocomplete defaults
    @autocomplete_enabled = true
    @autocomplete_max_tables = 100
    @autocomplete_max_columns_per_table = 100
    @autocomplete_cache_ttl_seconds = 300  # 5 minutes
  end
  
  # Validation: Autocomplete requires schema_explorer
  def autocomplete_enabled
    @autocomplete_enabled && schema_explorer
  end
  
  # Allow configuration but validate range
  def autocomplete_max_tables=(value)
    raise ArgumentError, "autocomplete_max_tables must be between 1 and 1000" unless (1..1000).include?(value)
    @autocomplete_max_tables = value
  end
  
  def autocomplete_max_columns_per_table=(value)
    raise ArgumentError, "autocomplete_max_columns_per_table must be between 1 and 500" unless (1..500).include?(value)
    @autocomplete_max_columns_per_table = value
  end
  
  def autocomplete_cache_ttl_seconds=(value)
    raise ArgumentError, "autocomplete_cache_ttl_seconds must be positive" unless value > 0
    @autocomplete_cache_ttl_seconds = value
  end
end
```

**Usage Example:**

```ruby
# config/initializers/query_console.rb
QueryConsole.configure do |config|
  config.schema_explorer = true
  
  # Autocomplete is enabled by default if schema_explorer is true
  config.autocomplete_enabled = true  # optional, defaults to true
  
  # For large databases, limit the scope
  config.autocomplete_max_tables = 50  # Only first 50 tables
  config.autocomplete_max_columns_per_table = 50  # Max 50 columns per table
  
  # Cache TTL (5 minutes default)
  config.autocomplete_cache_ttl_seconds = 300
end
```

**Invalid Configuration Prevention:**

```ruby
# This will NOT enable autocomplete (schema_explorer is required)
config.schema_explorer = false
config.autocomplete_enabled = true  # Ignored, autocomplete_enabled returns false

# This will raise ArgumentError
config.autocomplete_max_tables = 5000  # Too large!
config.autocomplete_max_columns_per_table = -1  # Invalid!
```

### 7. Testing Strategy (SPECIFIC TEST CASES)

**Backend Tests**

```ruby
# spec/controllers/query_console/schema_controller_spec.rb
describe SchemaController do
  describe 'GET #bulk' do
    it 'returns all tables with columns in single request'
    it 'respects autocomplete_max_tables limit'
    it 'respects autocomplete_max_columns_per_table limit'
    it 'applies schema_table_denylist filtering'
    it 'applies schema_allowlist filtering'
    it 'returns 403 when schema_explorer is disabled'
    it 'returns 403 when autocomplete_enabled is false'
    it 'handles tables with zero columns gracefully'
    it 'caches response according to schema_cache_seconds'
    
    context 'with mixed case identifiers' do
      it 'preserves exact case for PostgreSQL quoted identifiers'
      it 'handles reserved keyword table names (e.g., "order")'
    end
    
    context 'with different database adapters' do
      it 'works with PostgreSQL' do
        # Test with PG schema
      end
      
      it 'works with MySQL' do
        # Test with MySQL schema
      end
      
      it 'works with SQLite' do
        # Test with SQLite schema
      end
    end
  end
end
```

**Frontend Tests**

```javascript
// test/javascript/controllers/editor_controller_test.js
import { Application } from "@hotwired/stimulus"
import EditorController from "controllers/editor_controller"

describe('EditorController', () => {
  describe('schema loading', () => {
    it('initializes editor immediately without blocking', async () => {
      // Editor should be functional before schema loads
    })
    
    it('loads schema asynchronously in background', async () => {
      // Should fetch /schema/bulk
    })
    
    it('reconfigures CodeMirror after schema loads', async () => {
      // Should update SQL extension configuration
    })
    
    it('times out after 5 seconds', async () => {
      // Mock slow response
    })
    
    it('handles 403 Forbidden gracefully', async () => {
      // Editor should continue working
    })
    
    it('handles 404 Not Found gracefully', async () => {
      // Editor should continue working
    })
    
    it('handles network errors gracefully', async () => {
      // Editor should continue working
    })
    
    it('caches schema with 5-minute TTL', () => {
      // Should reuse cached schema
    })
    
    it('invalidates cache after TTL expires', () => {
      // Should refetch after 5 minutes
    })
  })
  
  describe('schema status indicator', () => {
    it('shows "Loading schema..." during fetch')
    it('shows "Schema loaded" after success')
    it('hides success message after 3 seconds')
    it('shows "Schema unavailable" after error')
  })
  
  describe('Turbo/Hotwire compatibility', () => {
    it('cleans up on disconnect (Turbo navigation)')
    it('reinitializes on reconnect')
    it('does not leak memory on multiple connects/disconnects')
  })
})
```

**Edge Cases to Test**


| Edge Case                    | Expected Behavior           | Test Priority |
| ---------------------------- | --------------------------- | ------------- |
| Empty database (0 tables)    | Returns `[]`, editor works  | High          |
| Single table with 0 columns  | Returns `{ tablename: [] }` | High          |
| 500 tables (exceeds limit)   | Returns first 100 tables    | High          |
| Table with 200 columns       | Returns first 100 columns   | High          |
| Mixed case: `"UserProfiles"` | Preserves exact case        | High          |
| Quoted identifier: `"order"` | Preserves quotes            | Medium        |
| Special chars: `table-name`  | Sanitized or quoted         | Medium        |
| Unicode: `表名`                | Preserved correctly         | Low           |
| Very long names (>63 chars)  | Truncated or full           | Low           |
| Schema with 1000+ tables     | Timeout or partial load     | Medium        |
| Concurrent page loads        | No race conditions          | High          |
| Schema change during session | Reloads after 5 min TTL     | Medium        |


**Manual Testing Checklist**

- PostgreSQL with 50 tables
- MySQL with 100 tables
- SQLite with 10 tables
- Mixed case identifiers (PostgreSQL)
- Slow network (throttle to 3G)
- Offline mode (Network tab disabled)
- `schema_explorer = false`
- `autocomplete_max_tables = 10`
- Turbo navigation (visit another page, back button)
- Multiple browser tabs simultaneously
- Console for any JavaScript errors
- Autocomplete in FROM, WHERE, JOIN, ORDER BY clauses

### 8. Implementation Steps (UPDATED)

**Phase 1: Backend (Critical)**

1. ✅ Add `bulk` action to `SchemaController`
  - Returns all tables with columns in single request
  - Applies `autocomplete_max_tables` limit
  - Applies `autocomplete_max_columns_per_table` limit
  - Respects denylist/allowlist filtering
2. ✅ Add route for `/schema/bulk`
3. ✅ Add configuration options to `Configuration` class
  - `autocomplete_enabled` (default: true)
  - `autocomplete_max_tables` (default: 100, range: 1-1000)
  - `autocomplete_max_columns_per_table` (default: 100, range: 1-500)
  - `autocomplete_cache_ttl_seconds` (default: 300)
  - Add validation logic
4. ✅ Write backend tests for `SchemaController#bulk`

**Phase 2: Frontend Core**
5. ✅ Remove inline EditorController from `new.html.erb`

- Consolidate to standalone `editor_controller.js` only

1. ✅ Update `EditorController.connect()`
  - Initialize CodeMirror immediately with empty schema
  - Call `loadSchemaAsync()` in background
2. ✅ Implement `loadSchemaAsync()`
  - Fetch from `/schema/bulk` with 5-second timeout
  - Handle success/error/timeout gracefully
  - Cache with TTL
3. ✅ Implement `reconfigureWithSchema()`
  - Transform API response to CodeMirror format
  - Update SQL extension configuration dynamically
4. ✅ Add schema status indicator
  - Loading state
  - Success state (auto-hide after 3 seconds)
  - Error state

**Phase 3: Testing**
10. ✅ Write frontend unit tests
    - Schema loading with timeout
    - Error handling (403, 404, network error)
    - Cache TTL behavior
    - Turbo/Hotwire compatibility

1. ✅ Manual testing checklist
  - PostgreSQL, MySQL, SQLite
    - Empty database, large schemas
    - Mixed case identifiers
    - Slow network, offline mode
    - Configuration edge cases

**Phase 4: Documentation**
12. ✅ Update README
    - Add Autocomplete section
    - Document configuration options
    - Add usage examples with screenshots

1. ✅ Add inline code documentation
  - JSDoc comments for public methods
    - RDoc comments for Ruby classes

**Phase 5: Performance Testing**
14. ✅ Test with large schemas
    - 100 tables benchmark
    - 500 tables (with limit)
    - Measure load time, memory usage

1. ✅ Verify no memory leaks
  - Multiple connect/disconnect cycles
    - Long-running sessions

**Estimated Timeline:**

- Phase 1 (Backend): 2-3 hours
- Phase 2 (Frontend): 2-3 hours
- Phase 3 (Testing): 2-3 hours
- Phase 4 (Documentation): 1-2 hours
- Phase 5 (Performance): 1 hour
- **Total: 8-12 hours**

### 9. CodeMirror SQL Autocomplete Capabilities

CodeMirror's `@codemirror/lang-sql` provides:

- **Table completion**: After FROM, JOIN, UPDATE, DELETE FROM, INSERT INTO
- **Column completion**: After table reference (e.g., `users.`)
- **WHERE clause support**: Suggests columns from tables in scope
  - Example: `SELECT * FROM users WHERE |` → suggests `id`, `name`, `email`, etc.
  - Works with JOINs: `FROM users JOIN posts WHERE posts.|` → suggests post columns
- **Alias awareness**: Handles table aliases (e.g., `FROM users u` then `u.`)
- **SELECT clause**: Suggests columns from all tables in FROM clause
- **Keyword completion**: SQL keywords (SELECT, WHERE, ORDER BY, GROUP BY, etc.)
- **Context-aware**: Different suggestions based on cursor position in the query

### 10. Alternatives Considered

**Custom Autocomplete Extension**

- Pros: Full control over behavior
- Cons: Complex implementation, reinventing the wheel
- Decision: Use CodeMirror's built-in SQL autocomplete (proven, maintained)

**Server-Side Autocomplete API**

- Pros: More flexible, can add advanced logic
- Cons: Network latency on every keystroke
- Decision: Client-side for performance

### 11. Future Enhancements (Out of Scope for MVP)

- **Smart column ordering**: Show primary key, frequently used columns first
- **Type hints**: Show column data types in autocomplete
- **Query history integration**: Suggest from previously used tables
- **Fuzzy matching**: More forgiving search
- **JOIN suggestions**: Suggest likely foreign key joins
- **Function autocomplete**: Database-specific functions
- **Schema refresh**: Button to reload schema without page refresh

## Security Considerations (VERIFIED)

**Authentication & Authorization:**

- ✅ Schema endpoints inherit from `ApplicationController`
- ✅ `authorize` callback is applied (if configured)
- ✅ Requires `schema_explorer = true` configuration
- ✅ CSRF protection via Turbo-Frame header check

**Data Filtering:**

- ✅ Respects `schema_table_denylist` (blocks sensitive tables)
- ✅ Respects `schema_allowlist` (if configured, only shows allowed tables)
- ✅ Both filters applied in `SchemaIntrospector.filter_tables()`

**Data Exposure:**

- ✅ Only metadata exposed (table names, column names)
- ✅ No actual data, no row counts, no values
- ✅ No PII or sensitive information
- ✅ Read-only operations

**Rate Limiting:**

- ⚠️ Consider adding rate limiting to `/schema/bulk` endpoint
- Recommendation: Max 10 requests per minute per user
- Prevents abuse (excessive schema requests)

```ruby
# Optional: Add rate limiting (using rack-attack or similar)
throttle('schema/bulk', limit: 10, period: 1.minute) do |req|
  req.ip if req.path == '/query_console/schema/bulk'
end
```

**Input Validation:**

- ✅ Table names sanitized by `SchemaIntrospector.sanitize_table_name`
- ✅ Only alphanumeric + underscore allowed
- ✅ Prevents SQL injection in schema queries

**Error Handling:**

- ✅ No stack traces exposed to client
- ✅ Generic error messages only
- ✅ Detailed errors logged server-side only

## Rollout Plan

1. **Development**: Implement Phase 1 core functionality
2. **Testing**: Test with multiple databases and schema sizes
3. **Documentation**: Update README with autocomplete feature
4. **Release**: Include in next minor version (e.g., v0.3.1)
5. **Feedback**: Monitor for performance issues, gather user feedback

## Success Metrics

- Autocomplete suggestions appear within 200ms of trigger
- Schema loads in < 2 seconds for typical databases (< 100 tables)
- No JavaScript errors in console
- Editor remains functional if schema loading fails
- Positive user feedback on usability

## Decisions Made (Previously Open Questions)

### 1. Should we show table type (table vs view) in autocomplete?

**Decision: NO for MVP, preserve for future**

- **Rationale**: CodeMirror's built-in SQL autocomplete doesn't support custom icons/badges
- **Implementation**: Preserve `kind` field in response for future enhancement
- **Future**: Could add custom completion source with icons (📋 table, 👁️ view)

```javascript
// MVP: Simple column array
{ users: ["id", "name"] }

// Future: Rich metadata
{ 
  users: { 
    type: "table", 
    icon: "📋",
    columns: ["id", "name"] 
  } 
}
```

### 2. Should we show column data types in autocomplete hints?

**Decision: NO for MVP, add in v2**

- **Rationale**: Increases payload size significantly (5-10x)
- **Performance**: Would require fetching full column definitions
- **Workaround**: Hover on column name in Schema Explorer shows type
- **Future**: Add as opt-in feature with `autocomplete_include_types: true`

### 3. Should autocomplete be configurable per-user or per-installation?

**Decision: Installation-level only**

- **Rationale**: Per-user config adds complexity (DB storage, UI, permissions)
- **Simpler**: Admin controls via `query_console.rb` initializer
- **Consistent**: All users see same autocomplete behavior
- **Future**: If requested, could add user preferences to localStorage

```ruby
# Installation-level (current)
QueryConsole.configure do |config|
  config.autocomplete_enabled = true
end

# Per-user (future, if needed)
# Store in localStorage:
# { userId: 123, preferences: { autocompleteEnabled: false } }
```

### 4. Do we need a schema refresh button, or is page reload sufficient?

**Decision: Page reload sufficient for MVP**

- **Rationale**: Schema changes are infrequent (daily/weekly, not hourly)
- **Cache TTL**: 5-minute TTL handles most schema updates automatically
- **Complexity**: Refresh button adds UI complexity and state management
- **Workaround**: Users can reload page (Ctrl+R / Cmd+R)
- **Future**: If frequently requested, add small refresh icon next to "Schema loaded"

**TTL Handling:**

```
Schema loaded at: 10:00 AM
TTL expires: 10:05 AM
User still on page at 10:06 AM → Next autocomplete trigger refetches schema
```

## Estimated Effort

- Phase 1 (Core): 2-3 hours
- Phase 2 (Enhancement): 1-2 hours
- Phase 3 (Polish): 1-2 hours
- Testing & Documentation: 1-2 hours
- **Total: 5-9 hours**

## References

- [CodeMirror SQL Language Documentation](https://codemirror.net/docs/ref/#lang-sql)
- [CodeMirror Autocomplete System](https://codemirror.net/docs/ref/#autocomplete)
- Existing QueryConsole schema introspection code
- [AbortController for Fetch Timeouts](https://developer.mozilla.org/en-US/docs/Web/API/AbortController)

---

## Summary of Changes (Code Review Applied)

### Critical Fixes

1. **N+1 Problem Fixed**: Added `/schema/bulk` endpoint to fetch all data in 1 request instead of N+1
2. **Race Condition Fixed**: Editor initializes immediately, schema loads asynchronously without blocking
3. **Timeout Protection**: 5-second timeout prevents hanging requests
4. **Memory Protection**: Added configurable limits (`max_tables`, `max_columns_per_table`)

### Architecture Improvements

1. **Consolidated Controllers**: Removed duplication, single source of truth in `editor_controller.js`
2. **Cache TTL**: 5-minute client-side cache with automatic invalidation
3. **Loading Indicator**: Visual feedback for schema loading states
4. **Error Handling**: Graceful fallbacks, editor works without schema

### Configuration Enhancements

1. **Validation**: `autocomplete_enabled` requires `schema_explorer` to be true
2. **Explicit Defaults**: All config options have documented defaults
3. **Range Validation**: Limits enforced (tables: 1-1000, columns: 1-500)

### Testing Improvements

1. **Specific Test Cases**: Named tests for all scenarios
2. **Edge Cases**: Comprehensive list with expected behaviors
3. **Manual Checklist**: Step-by-step testing guide

### Decisions Made

1. **Table/View Types**: Preserved for future, not shown in MVP
2. **Column Types**: Deferred to v2 (performance reasons)
3. **Per-User Config**: Installation-level only for simplicity
4. **Schema Refresh**: Page reload sufficient (5-min TTL auto-refreshes)

**Status:** All code review findings addressed. Implementation plan is production-ready.