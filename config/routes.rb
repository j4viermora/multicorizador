Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }

  authenticate :user, ->(user) { user.super_admin? } do
    mount MissionControl::Jobs::Engine, at: "/jobs"
  end

  namespace :admin do
    get "dashboard", to: "dashboard#index"
    resources :providers do
      member { patch :toggle_active }
    end
    resources :insurance_plans
    resources :policies, only: [ :index, :show ]
    resources :users, only: [ :index, :show, :edit, :update ] do
      member { patch :approve }
    end
  end

  namespace :producer do
    get "dashboard", to: "dashboard#index"
    resources :quotes
    resources :travelers
    resources :policies, only: [ :index, :show ]
  end

  namespace :public do
    resources :quotes, only: [ :show, :update ], param: :token
  end

  # Public landing page per company
  get  "cotizar/:slug", to: "public/landing#show", as: :public_landing
  post "cotizar/:slug", to: "public/landing#create"
  get  "cotizar/:slug/resultados/:token", to: "public/landing#results", as: :public_landing_results
  post "cotizar/:slug/comprar", to: "public/landing#purchase", as: :public_landing_purchase
  post "cotizar/:slug/checkout", to: "public/landing#checkout", as: :public_landing_checkout

  resources :webhooks, only: [ :create ], param: :provider_slug

  get "account/pending", to: "account#pending", as: :account_pending

  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"
end
