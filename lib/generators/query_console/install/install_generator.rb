require 'rails/generators'

module QueryConsole
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      desc "Creates a QueryConsole initializer in your application."

      def copy_initializer
        template "query_console.rb", "config/initializers/query_console.rb"
      end

      def show_readme
        readme "README" if behavior == :invoke
      end
    end
  end
end
