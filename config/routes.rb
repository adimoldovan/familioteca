Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get "sign_in", to: "sessions#new", as: :sign_in
  post "session", to: "sessions#create", as: :session
  delete "session", to: "sessions#destroy"

  namespace :admin do
    resources :members, only: [ :index ]
    resources :ingestions, only: [ :create ]
    resources :books, only: [ :index, :edit, :update ]
  end

  resources :books, only: [ :show ] do
    resource :member_book, only: [ :update ], controller: "member_books"
    resources :kindle_deliveries, only: [ :create ]
  end
  get "books/:id/download", to: "downloads#show", as: :download_book

  constraints ->(_) { Rails.env.e2e? } do
    namespace :e2e do
      post "seed_user", to: "seed_user#create"
      post "seed_book", to: "seed_book#create"
    end
  end

  root "books#index"
end
