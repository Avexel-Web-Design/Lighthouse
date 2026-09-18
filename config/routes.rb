Rails.application.routes.draw do
  devise_for :users, controllers: { sessions: "users/sessions" }

  root "dashboard#index"

  # PWA files served from app/views/pwa/*
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :users, except: [ :show ]

  resources :web_push_subscriptions, only: [ :create ] do
    collection do
      post :test_notification
      delete :unsubscribe
    end
  end

  resources :events do
    member do
      post :select
      post :sync
      get :offline_manifest
    end
  end

  get "scouting_entries/replay", to: "scouting_entries#replay", as: :replay_scouting_entries

  resources :scouting_entries do
    member do
      post :approve
    end

    collection do
      post :sync
    end
  end

  resources :scouting_assignments, only: [ :index, :destroy ] do
    collection do
      post :bulk_create
      post :bulk_destroy
      post :toggle
    end
  end

  # QR code offline import (analysts/admins scan scout QR codes)
  resources :qr_imports, only: [] do
    collection do
      get :scanner
      post :import
    end
  end

  resources :pit_scouting_entries do
    collection do
      post :sync
    end
  end

  resources :teams, only: [ :index, :show ]

  # Team comparison with query params: /compare?teams=1,2,3
  resource :team_comparison, only: [ :show ], controller: "team_comparisons"

  resources :pick_lists

  resources :data_conflicts, only: [ :index ] do
    member do
      post :resolve
    end
  end

  resource :match_simulator, only: [ :new, :create ], controller: "match_simulator"

  # Predictions
  resources :predictions, only: [ :index, :show ] do
    collection do
      post :generate
    end
  end

  # Exports
  scope :exports, controller: :exports do
    get :csv, as: :exports_csv
    get :pdf, as: :exports_pdf
    get :excel, as: :exports_excel
    get :json, as: :exports_json
  end

  namespace :api do
    namespace :v1 do
      resources :scouting_entries, only: [ :create ] do
        collection do
          post :bulk_sync
        end
      end

      resources :pit_scouting_entries, only: [ :create ] do
        collection do
          post :bulk_sync
        end
      end

      resources :exports, only: [] do
        collection do
          get :scouting_data
        end
      end
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
