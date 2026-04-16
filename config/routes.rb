QueryConsole::Engine.routes.draw do
  root to: "queries#new"
  post "run", to: "queries#run"
  post "explain", to: "explain#create"
  
  # Schema introspection endpoints
  get "schema/tables", to: "schema#tables"
  get "schema/bulk", to: "schema#bulk"
  get "schema/tables/:name", to: "schema#show", as: :schema_table
end
