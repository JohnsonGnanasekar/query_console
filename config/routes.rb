QueryConsole::Engine.routes.draw do
  root to: "queries#new"
  post "run", to: "queries#run"
end
