import { Controller } from "@hotwired/stimulus"

// Manages query history stored in localStorage
// Usage: <div data-controller="history">
export default class extends Controller {
  static targets = ["list", "item", "emptyMessage"]
  static values = {
    storageKey: { type: String, default: "query_console.history.v1" },
    maxItems: { type: Number, default: 20 }
  }

  connect() {
    this.loadHistory()
  }

  // Add query to history after successful execution
  add(event) {
    const sql = event.detail.sql
    const timestamp = event.detail.timestamp || new Date().toISOString()
    
    const history = this.getHistory()
    
    // Add new item to beginning
    history.unshift({
      sql: sql.trim(),
      timestamp: timestamp
    })
    
    // Keep only max items
    const trimmed = history.slice(0, this.maxItemsValue)
    this.saveHistory(trimmed)
    this.renderHistory(trimmed)
  }

  // Load query from history into editor
  load(event) {
    event.preventDefault()
    const sql = event.currentTarget.dataset.sql
    
    // Dispatch custom event that editor controller will listen to
    this.dispatch("load", { detail: { sql } })
  }

  // Clear all history
  clear(event) {
    event.preventDefault()
    
    if (confirm("Clear all query history?")) {
      localStorage.removeItem(this.storageKeyValue)
      this.renderHistory([])
    }
  }

  // Private methods

  loadHistory() {
    const history = this.getHistory()
    this.renderHistory(history)
  }

  getHistory() {
    const stored = localStorage.getItem(this.storageKeyValue)
    return stored ? JSON.parse(stored) : []
  }

  saveHistory(history) {
    localStorage.setItem(this.storageKeyValue, JSON.stringify(history))
  }

  renderHistory(history) {
    if (history.length === 0) {
      this.listTarget.innerHTML = '<li class="empty-history">No query history yet</li>'
      return
    }

    this.listTarget.innerHTML = history.map((item, index) => `
      <li class="history-item">
        <button 
          type="button"
          class="history-item-button" 
          data-action="click->history#load"
          data-sql="${this.escapeHtml(item.sql)}"
          title="${this.escapeHtml(item.sql)}">
          <div class="history-item-sql">${this.escapeHtml(this.truncate(item.sql, 100))}</div>
          <div class="history-item-time">${this.formatTime(item.timestamp)}</div>
        </button>
      </li>
    `).join('')
  }

  truncate(str, length) {
    return str.length > length ? str.substring(0, length) + '...' : str
  }

  formatTime(timestamp) {
    const date = new Date(timestamp)
    const now = new Date()
    const diff = now - date
    
    // Less than 1 minute
    if (diff < 60000) return 'just now'
    
    // Less than 1 hour
    if (diff < 3600000) {
      const minutes = Math.floor(diff / 60000)
      return `${minutes}m ago`
    }
    
    // Less than 24 hours
    if (diff < 86400000) {
      const hours = Math.floor(diff / 3600000)
      return `${hours}h ago`
    }
    
    // More than 24 hours
    return date.toLocaleDateString()
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
