module QueryConsole
  class Engine < ::Rails::Engine
    isolate_namespace QueryConsole

    config.generators do |g|
      g.test_framework :rspec
    end

    # Ensure engine assets and views are available
    config.eager_load_paths << File.expand_path("../app/services", __dir__)
  end
end
