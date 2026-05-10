Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: 'users/registrations' }

  authenticate :user, ->(user) { user.super_admin? } do
    mount MissionControl::Jobs::Engine, at: "/jobs"
  end

  namespace :admin do
    get "dashboard", to: "dashboard#index"
    resources :providers
    resources :insurance_plans
    resources :commission_contracts
    resources :users, only: [:index, :show, :edit, :update] do
      member { patch :approve }
    end
    resources :finances, only: [:index]
    resources :platform_invoices
  end

  namespace :producer do
    get "dashboard", to: "dashboard#index"
    resources :quotes
    resources :travelers
    resources :policies, only: [:index, :show]
    resources :commissions, only: [:index]
    resources :invoices, only: [:index, :show, :create]
  end

  namespace :public do
    resources :quotes, only: [:show, :update], param: :token
  end

  # Public landing page per company
  get  "cotizar/:slug", to: "public/landing#show", as: :public_landing
  post "cotizar/:slug", to: "public/landing#create"
  post "cotizar/:slug/comprar", to: "public/landing#purchase", as: :public_landing_purchase
  post "cotizar/:slug/checkout", to: "public/landing#checkout", as: :public_landing_checkout
  get  "cotizar/:slug/gracias", to: "public/landing#thanks", as: :public_landing_thanks

  resources :webhooks, only: [:create], param: :provider_slug

  get "account/pending", to: "account#pending", as: :account_pending

  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"
end
