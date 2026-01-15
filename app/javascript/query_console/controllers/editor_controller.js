import { Controller } from "@hotwired/stimulus"

// Manages the SQL editor textarea and query execution
// Usage: <div data-controller="editor">
export default class extends Controller {
  static targets = ["textarea", "runButton", "clearButton", "results"]

  connect() {
    // Listen for history load events
    this.element.addEventListener('history:load', (event) => {
      this.loadQuery(event.detail.sql)
    })
  }

  // Load query into textarea (from history)
  loadQuery(sql) {
    this.textareaTarget.value = sql
    this.textareaTarget.focus()
    
    // Scroll to editor
    this.element.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }

  // Clear textarea
  clear(event) {
    event.preventDefault()
    this.textareaTarget.value = ''
    this.textareaTarget.focus()
  }

  // Handle form submission
  submit(event) {
    const sql = this.textareaTarget.value.trim()
    
    if (!sql) {
      event.preventDefault()
      alert('Please enter a SQL query')
      return
    }

    // Show loading state
    this.runButtonTarget.disabled = true
    this.runButtonTarget.textContent = 'Running...'
    
    // After Turbo completes the request, we'll handle success/error
  }

  // Called after successful query execution (via Turbo)
  querySuccess(event) {
    // Re-enable button
    this.runButtonTarget.disabled = false
    this.runButtonTarget.textContent = 'Run Query'
    
    // Dispatch event to add to history
    const sql = this.textareaTarget.value.trim()
    this.dispatch('executed', { 
      detail: { 
        sql: sql,
        timestamp: new Date().toISOString()
      },
      target: document.querySelector('[data-controller="history"]')
    })
  }

  // Called after failed query execution
  queryError(event) {
    this.runButtonTarget.disabled = false
    this.runButtonTarget.textContent = 'Run Query'
  }

  // Handle Turbo Frame errors
  turboFrameError(event) {
    console.error('Turbo Frame error:', event.detail)
    this.runButtonTarget.disabled = false
    this.runButtonTarget.textContent = 'Run Query'
  }
}
