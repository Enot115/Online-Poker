Rails.application.routes.draw do
  root "home#show"
  get "/registration", to: "users#new", as: :registration
  post "/registration", to: "users#create"
  get "/login", to: "sessions#new", as: :login
  post "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy", as: :logout
  get "/tables/:id", to: "pages#table", as: :table
  get "/earn", to: "pages#earn", as: :earn_chips
  get "/profile", to: "pages#profile", as: :profile
end
