import { Controller } from "@hotwired/stimulus"
import { EditorView, keymap } from "@codemirror/view"
import { EditorState } from "@codemirror/state"
import { sql } from "@codemirror/lang-sql"
import { defaultKeymap } from "@codemirror/commands"
import { autocompletion } from "@codemirror/autocomplete"

// Manages the SQL editor with CodeMirror and query execution
// Usage: <div data-controller="editor">
export default class extends Controller {
  static targets = ["container"]

  connect() {
    this.initializeCodeMirror()
    
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

  initializeCodeMirror() {
    const sqlLanguage = sql()
    
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
  getSql() {
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

  // Run query
  runQuery() {
    const sql = this.getSql().trim()
    if (!sql) {
      alert('Please enter a SQL query')
      return
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
