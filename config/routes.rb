Rails.application.routes.draw do
  root "home#show"
  mount ActionCable.server => "/cable"

  get "/registration", to: "users#new", as: :registration
  post "/registration", to: "users#create"
  
  get "/login", to: "sessions#new", as: :login
  post "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy", as: :logout
  
  get "/tables/:id", to: "pages#table", as: :table
  post "/tables/:id/join", to: "poker_tables#join", as: :join_table
  delete "/tables/:id/leave", to: "poker_tables#leave", as: :leave_table
  post "/tables/:id/actions", to: "poker_tables#action", as: :table_action
  post "/tables/:id/next-hand", to: "poker_tables#next_hand", as: :next_hand
  get "/earn", to: "pages#earn", as: :earn_chips
  post "/daily-challenge/solve", to: "daily_challenge_completions#create", as: :solve_daily_challenge
  get "/profile", to: "pages#profile", as: :profile
end
