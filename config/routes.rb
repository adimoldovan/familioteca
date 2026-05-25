Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get "sign_in", to: "sessions#new", as: :sign_in
  post "session", to: "sessions#create", as: :session
  delete "session", to: "sessions#destroy"

  resources :password_resets, only: %i[edit update], param: :token

  get "register/:code", to: "registrations#new", as: :register
  post "register/:code", to: "registrations#create"

  namespace :admin do
    resources :members, only: [ :index ] do
      post :reset_link, on: :member
    end
    resources :ingestions, only: [ :create ]
    resources :books, only: [ :index, :edit, :update, :destroy ] do
      post :rescan, on: :member
    end
  end

  resource :account, only: [ :show, :update ]

  resources :books, only: [ :show ] do
    resource :member_book, only: [ :update ], controller: "member_books"
    resources :kindle_deliveries, only: [ :create ]
  end
  get "books/:id/download", to: "downloads#show", as: :download_book

  constraints ->(_) { Rails.env.e2e? } do
    namespace :e2e do
      post "seed_user", to: "seed_user#create"
      post "seed_book", to: "seed_book#create"
      post "perform_jobs", to: "perform_jobs#create"
    end
  end

  root "books#index"
end
