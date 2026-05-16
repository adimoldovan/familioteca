Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get "sign_in", to: "sessions#new", as: :sign_in
  post "session", to: "sessions#create", as: :session
  delete "session", to: "sessions#destroy"

  root "books#index"
end
