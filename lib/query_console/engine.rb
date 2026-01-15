module QueryConsole
  class Engine < ::Rails::Engine
    isolate_namespace QueryConsole

    config.generators do |g|
      g.test_framework :rspec
    end

    # Ensure engine assets and views are available
    config.eager_load_paths << File.expand_path("../app/services", __dir__)
    
    # Configure paths for JavaScript
    config.assets.paths << root.join("app/javascript")
    
    initializer "query_console.assets" do |app|
      app.config.assets.precompile += %w[
        query_console/application.js
        query_console/controllers/*.js
      ]
    end
    
    # Load Hotwire (Turbo & Stimulus)
    initializer "query_console.importmap", before: "importmap" do |app|
      if app.config.respond_to?(:importmap)
        app.config.importmap.paths << root.join("config/importmap.rb")
      end
    end
    
    # Ensure Turbo and Stimulus are available
    initializer "query_console.hotwire" do |app|
      unless defined?(Turbo)
        require "turbo-rails"
      end
      unless defined?(Stimulus)
        require "stimulus-rails"
      end
    end
  end
end
