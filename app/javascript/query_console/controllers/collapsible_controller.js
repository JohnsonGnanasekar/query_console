import { Controller } from "@hotwired/stimulus"

// Handles collapsible sections (banner, editor, history)
// Usage: <div data-controller="collapsible" data-collapsible-key-value="banner">
export default class extends Controller {
  static values = {
    key: String  // Storage key suffix (e.g., "banner", "editor", "history")
  }

  connect() {
    this.storageKey = `query_console.${this.keyValue}_collapsed`
    this.loadState()
  }

  toggle(event) {
    event.preventDefault()
    this.element.classList.toggle('collapsed')
    
    const isCollapsed = this.element.classList.contains('collapsed')
    this.saveState(isCollapsed)
    this.updateToggleButton(event.target, isCollapsed)
  }

  loadState() {
    const isCollapsed = localStorage.getItem(this.storageKey) === 'true'
    if (isCollapsed) {
      this.element.classList.add('collapsed')
      const button = this.element.querySelector('.section-toggle, .banner-toggle')
      if (button) {
        this.updateToggleButton(button, true)
      }
    }
  }

  saveState(isCollapsed) {
    localStorage.setItem(this.storageKey, isCollapsed ? 'true' : 'false')
  }

  updateToggleButton(button, isCollapsed) {
    button.textContent = isCollapsed ? '▲' : '▼'
  }
}
