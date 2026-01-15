Rails.application.routes.draw do
  mount QueryConsole::Engine, at: "/query_console"
end
