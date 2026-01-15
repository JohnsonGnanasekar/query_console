# Configure JavaScript module imports for QueryConsole engine
# This uses importmap-rails to manage JavaScript dependencies without bundling

# Pin Hotwire dependencies
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"

# Pin CodeMirror 6 from CDN
pin "@codemirror/state", to: "https://cdn.jsdelivr.net/npm/@codemirror/state@6.4.0/+esm"
pin "@codemirror/view", to: "https://cdn.jsdelivr.net/npm/@codemirror/view@6.23.0/+esm"
pin "@codemirror/language", to: "https://cdn.jsdelivr.net/npm/@codemirror/language@6.10.0/+esm"
pin "@codemirror/commands", to: "https://cdn.jsdelivr.net/npm/@codemirror/commands@6.3.3/+esm"
pin "@codemirror/lang-sql", to: "https://cdn.jsdelivr.net/npm/@codemirror/lang-sql@6.6.0/+esm"
pin "@codemirror/autocomplete", to: "https://cdn.jsdelivr.net/npm/@codemirror/autocomplete@6.13.0/+esm"

# Pin application and controllers
pin "query_console/application", to: "query_console/application.js"
pin_all_from File.expand_path("../app/javascript/controllers/query_console", __dir__), 
             under: "controllers/query_console", 
             to: "query_console/controllers"
