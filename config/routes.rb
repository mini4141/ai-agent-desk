Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # Action Cable: browser channels at /cable, phone-line simulator at /phone-sim/stream.
  mount ActionCable.server => "/cable"
  mount ActionCable.server => "/phone-sim/stream"

  namespace :api do
    namespace :v1 do
      resource :session, only: %i[create destroy]
      get "companies/me", to: "companies#show"
      patch "companies/me", to: "companies#update"
      resources :knowledge_sources, only: %i[index create] do
        post :reindex, on: :member
      end
      resources :tools, only: %i[index create] do
        post :test, on: :member
      end
      resources :conversations, only: %i[index show] do
        member do
          post :assign
          post :handback
          post :resolve
          post :messages, action: :create_message
          patch :tags
        end
      end
      get "metrics", to: "metrics#index"
      get "metrics/latency", to: "metrics#latency"
      post "metrics/rollup", to: "metrics#rollup"
      get "experiments", to: "experiments#index"
    end
  end

  namespace :widget do
    namespace :v1 do
      post "sessions", to: "sessions#create"
      post "conversations/:id/csat", to: "csat#create"
    end
  end

  # Public read-only API used by the Next.js help center.
  get "public/v1/:slug/articles", to: "public/articles#index"
  get "public/v1/:slug/articles/:id", to: "public/articles#show"
end
