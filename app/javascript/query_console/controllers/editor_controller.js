import { Controller } from "@hotwired/stimulus"
import { EditorView, keymap } from "@codemirror/view"
import { EditorState, StateEffect } from "@codemirror/state"
import { sql } from "@codemirror/lang-sql"
import { defaultKeymap } from "@codemirror/commands"
import { autocompletion } from "@codemirror/autocomplete"

// Manages the SQL editor with CodeMirror and query execution
// Usage: <div data-controller="editor" data-editor-schema-path-value="/query_console/schema">
export default class extends Controller {
  static targets = ["container", "schemaStatus"]
  static values = { schemaPath: String }

  connect() {
    this.schemaCache = null
    
    // 1. Initialize editor IMMEDIATELY (non-blocking)
    this.initializeCodeMirror({})
    
    // 2. Load schema asynchronously in background
    this.loadSchemaAsync()
    
    // Listen for history load events
    this.element.addEventListener('history:load', (event) => {
      this.loadQuery(event.detail.sql)
    })
  }

  disconnect() {
    if (this.view) {
      this.view.destroy()
    }
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
      const response = await fetch(this.schemaPathValue.replace('/tables', '/bulk'), {
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
    // Store schema data
    this.schemaData = schemaData
    
    // Build CodeMirror schema format
    const schemaConfig = {}
    
    schemaData.forEach(table => {
      schemaConfig[table.name] = table.columns
    })
    
    // Helper function to extract table names from SQL query
    // Enhanced SQL parser: extracts table names from queries
    // Supports: SELECT, UPDATE, INSERT, DELETE, FROM, JOIN, WITH clauses
    // Handles: Table aliases, schema-qualified names, multiple JOINs, CTEs
    const getTablesFromQuery = (sql) => {
      if (!sql || typeof sql !== 'string') return []
      
      const tables = []
      const sqlUpper = sql.toUpperCase()
      
      // Match UPDATE: UPDATE table_name SET
      const updateMatch = sqlUpper.match(/\bUPDATE\s+([\w.]+)/i)
      if (updateMatch && updateMatch[1]) {
        tables.push(updateMatch[1].toLowerCase())
      }
      
      // Match INSERT INTO: INSERT INTO table_name
      const insertMatch = sqlUpper.match(/\bINSERT\s+INTO\s+([\w.]+)/i)
      if (insertMatch && insertMatch[1]) {
        tables.push(insertMatch[1].toLowerCase())
      }
      
      // Match DELETE FROM: DELETE FROM table_name
      const deleteMatch = sqlUpper.match(/\bDELETE\s+FROM\s+([\w.]+)/i)
      if (deleteMatch && deleteMatch[1]) {
        tables.push(deleteMatch[1].toLowerCase())
      }
      
      // Match FROM clause: FROM table_name or FROM table1, table2
      // Enhanced: Stops at WHERE/JOIN/etc, handles aliases, excludes subqueries
      const fromMatch = sqlUpper.match(/\bFROM\s+([\w.,\s]+?)(?:\s+WHERE|\s+JOIN|\s+LEFT|\s+RIGHT|\s+INNER|\s+OUTER|\s+CROSS|\s+GROUP|\s+ORDER|\s+LIMIT|\s+OFFSET|\s*;|\s*$)/i)
      if (fromMatch && fromMatch[1]) {
        // Split by comma and clean up
        const tableList = fromMatch[1]
          .split(',')
          .map(t => t.trim())
          .filter(t => t && !t.includes('(')) // Exclude subqueries
          .map(t => {
            // Remove AS aliases: "users u" -> "users", "users AS u" -> "users"
            const parts = t.split(/\s+/)
            return parts[0].toLowerCase()
          })
        tables.push(...tableList)
      }
      
      // Match JOIN clauses: JOIN table_name
      // Enhanced: Handles LEFT/RIGHT/INNER/OUTER/CROSS JOIN
      const joinPattern = /(?:LEFT\s+|RIGHT\s+|INNER\s+|OUTER\s+|CROSS\s+)?JOIN\s+([\w.]+)/gi
      const joinMatches = sql.matchAll(joinPattern)
      for (const match of joinMatches) {
        if (match[1] && !match[1].includes('(')) {
          tables.push(match[1].toLowerCase())
        }
      }
      
      // Match WITH (CTE) clause table names: WITH table_name AS (...)
      const ctePattern = /\bWITH\s+([\w.]+)\s+AS/gi
      const cteMatches = sql.matchAll(ctePattern)
      for (const match of cteMatches) {
        if (match[1]) {
          tables.push(match[1].toLowerCase())
        }
      }
      
      // Remove duplicates and filter out empty/invalid names
      return [...new Set(tables)].filter(t => t && t.length > 0 && /^[\w.]+$/.test(t))
    }
    
    // Create custom completion source for columns
    const customCompletions = (context) => {
      const word = context.matchBefore(/\w*/)
      if (!word || (word.from == word.to && !context.explicit)) return null
      
      // Get the full SQL text before cursor
      const textBeforeCursor = context.state.doc.sliceString(0, context.pos)
      const textBeforeCursorUpper = textBeforeCursor.toUpperCase()
      
      // Extract tables from the query
      const tablesInQuery = getTablesFromQuery(textBeforeCursor)
      
      // Check if we're in a SET clause (UPDATE ... SET)
      const inSetClause = /\bUPDATE\s+\w+\s+SET\s/i.test(textBeforeCursor)
      
      // Check if we're in INSERT column list
      const inInsertColumns = /\bINSERT\s+INTO\s+\w+\s*\(/i.test(textBeforeCursor) && 
                              !textBeforeCursorUpper.includes('VALUES')
      
      // Build completions
      const options = []
      
      // If no tables found yet, suggest table names only
      if (tablesInQuery.length === 0) {
        schemaData.forEach(table => {
          options.push({
            label: table.name,
            type: "type",
            info: `Table (${table.columns.length} columns)`
          })
        })
      } else {
        // Add columns only from tables that are referenced
        schemaData.forEach(table => {
          if (tablesInQuery.includes(table.name.toLowerCase())) {
            table.columns.forEach(col => {
              options.push({
                label: col,
                type: "property",
                detail: table.name,
                info: `Column from ${table.name}`
              })
            })
          }
        })
        
        // Only add table names if NOT in SET or INSERT column list
        // (table names are useful for JOIN but not in SET/INSERT contexts)
        if (!inSetClause && !inInsertColumns) {
          schemaData.forEach(table => {
            options.push({
              label: table.name,
              type: "type",
              info: `Table (${table.columns.length} columns)`
            })
          })
        }
      }
      
      return {
        from: word.from,
        options: options,
        validFor: /^\w*$/
      }
    }
    
    // Create new SQL extension with schema
    const sqlExt = sql({ 
      schema: schemaConfig,
      upperCaseKeywords: false
    })
    
    // Reconfigure the view with custom completions
    this.view.dispatch({
      effects: StateEffect.reconfigure.of([
        sqlExt,
        autocompletion({
          override: [customCompletions],
          activateOnTyping: true
        }),
        keymap.of(defaultKeymap),
        EditorView.lineWrapping,
        EditorView.theme({
          "&": {
            fontSize: "14px",
            border: "1px solid #ddd",
            borderRadius: "4px"
          },
          ".cm-content": {
            fontFamily: "'Monaco', 'Menlo', 'Courier New', monospace",
            minHeight: "200px",
            padding: "12px"
          },
          ".cm-scroller": {
            overflow: "auto"
          },
          "&.cm-focused": {
            outline: "none"
          },
          ".cm-tooltip-autocomplete": {
            zIndex: 1000
          }
        })
      ])
    })
  }

  showSchemaStatus(status) {
    if (!this.hasSchemaStatusTarget) return
    
    const statusElement = this.schemaStatusTarget
    statusElement.className = `schema-status ${status}`
    
    switch(status) {
      case 'loading':
        statusElement.textContent = '⟳ Loading schema...'
        statusElement.style.display = 'inline-block'
        break
      case 'loaded':
        statusElement.textContent = '✓ Schema loaded'
        statusElement.style.display = 'inline-block'
        setTimeout(() => statusElement.style.display = 'none', 3000)
        break
      case 'error':
        statusElement.textContent = '⚠ Schema unavailable'
        statusElement.style.display = 'inline-block'
        break
    }
  }

  initializeCodeMirror(schemaConfig = {}) {
    const sqlLanguage = sql({ schema: schemaConfig })
    
    const startState = EditorState.create({
      doc: "SELECT * FROM users LIMIT 10;",
      extensions: [
        sqlLanguage.extension,
        autocompletion(),
        keymap.of(defaultKeymap),
        EditorView.lineWrapping,
        EditorView.theme({
          "&": {
            fontSize: "14px",
            border: "1px solid #ddd",
            borderRadius: "4px"
          },
          ".cm-content": {
            fontFamily: "'Monaco', 'Menlo', 'Courier New', monospace",
            minHeight: "200px",
            padding: "12px"
          },
          ".cm-scroller": {
            overflow: "auto"
          },
          "&.cm-focused": {
            outline: "none"
          },
          ".cm-tooltip-autocomplete": {
            zIndex: 1000
          }
        })
      ]
    })

    this.view = new EditorView({
      state: startState,
      parent: this.containerTarget
    })
  }

  // Get SQL content from CodeMirror
  // If text is selected, returns only the selection; otherwise returns full document
  getSql() {
    const selection = this.view.state.selection.main
    
    // If there's a selection (not just a cursor), use it
    if (selection.from !== selection.to) {
      return this.view.state.sliceDoc(selection.from, selection.to)
    }
    
    // Otherwise, return the full document
    return this.view.state.doc.toString()
  }

  // Set SQL content in CodeMirror
  setSql(text) {
    this.view.dispatch({
      changes: {
        from: 0,
        to: this.view.state.doc.length,
        insert: text
      }
    })
    this.view.focus()
  }

  // Insert text at cursor position
  insertAtCursor(text) {
    const selection = this.view.state.selection.main
    this.view.dispatch({
      changes: {
        from: selection.from,
        to: selection.to,
        insert: text
      },
      selection: {
        anchor: selection.from + text.length
      }
    })
    this.view.focus()
  }

  // Load query into editor (from history)
  loadQuery(sql) {
    this.setSql(sql)
    
    // Scroll to editor
    this.element.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }

  // Clear editor
  clearEditor() {
    this.setSql('')
    
    // Clear query results
    const queryFrame = document.querySelector('turbo-frame#query-results')
    if (queryFrame) {
      queryFrame.innerHTML = '<div style="color: #6c757d; text-align: center; padding: 40px; margin-top: 20px;"><p>Enter a query above and click "Run Query" to see results here.</p></div>'
    }
    
    // Clear explain results
    const explainFrame = document.querySelector('turbo-frame#explain-results')
    if (explainFrame) {
      explainFrame.innerHTML = ''
    }
  }

  // Check if query is a DML operation
  isDmlQuery(sql) {
    const trimmed = sql.trim().toLowerCase()
    return /^(insert|update|delete|merge)\b/.test(trimmed)
  }

  // Run query
  runQuery() {
    const sql = this.getSql().trim()
    if (!sql) {
      alert('Please enter a SQL query')
      return
    }
    
    // Check if it's a DML query and confirm with user
    if (this.isDmlQuery(sql)) {
      const confirmed = confirm(
        '⚠️ DATA MODIFICATION WARNING\n\n' +
        'This query will INSERT, UPDATE, or DELETE data.\n\n' +
        '• All changes are PERMANENT and cannot be undone\n' +
        '• All operations are logged\n\n' +
        'Do you want to proceed?'
      )
      
      if (!confirmed) {
        return // User cancelled
      }
    }
    
    // Clear explain results when running query
    const explainFrame = document.querySelector('turbo-frame#explain-results')
    if (explainFrame) {
      explainFrame.innerHTML = ''
    }
    
    // Store for history
    window._lastExecutedSQL = sql
    
    // Get CSRF token
    const csrfToken = document.querySelector('meta[name=csrf-token]')?.content
    
    // Create form with Turbo Frame target
    const form = document.createElement('form')
    form.method = 'POST'
    form.action = this.element.dataset.runPath
    form.setAttribute('data-turbo-frame', 'query-results')
    form.innerHTML = `
      <input type="hidden" name="sql" value="${this.escapeHtml(sql)}">
      <input type="hidden" name="authenticity_token" value="${csrfToken}">
    `
    document.body.appendChild(form)
    form.requestSubmit()
    document.body.removeChild(form)
  }

  // Explain query
  explainQuery() {
    const sql = this.getSql().trim()
    if (!sql) {
      alert('Please enter a SQL query')
      return
    }
    
    // Clear query results when running explain
    const queryFrame = document.querySelector('turbo-frame#query-results')
    if (queryFrame) {
      queryFrame.innerHTML = ''
    }
    
    // Get CSRF token
    const csrfToken = document.querySelector('meta[name=csrf-token]')?.content
    
    // Create form with Turbo Frame target
    const form = document.createElement('form')
    form.method = 'POST'
    form.action = this.element.dataset.explainPath
    form.setAttribute('data-turbo-frame', 'explain-results')
    form.innerHTML = `
      <input type="hidden" name="sql" value="${this.escapeHtml(sql)}">
      <input type="hidden" name="authenticity_token" value="${csrfToken}">
    `
    document.body.appendChild(form)
    form.requestSubmit()
    document.body.removeChild(form)
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
