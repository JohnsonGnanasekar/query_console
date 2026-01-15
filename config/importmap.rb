# Configure JavaScript module imports for QueryConsole engine
# This uses importmap-rails to manage JavaScript dependencies without bundling

# Pin Hotwire dependencies
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"

# Pin application and controllers
pin "query_console/application", to: "query_console/application.js"
pin_all_from File.expand_path("../app/javascript/controllers/query_console", __dir__), 
             under: "controllers/query_console", 
             to: "query_console/controllers"
