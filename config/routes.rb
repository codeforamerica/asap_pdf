require "sidekiq/web"

Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: "users/sessions",
    passwords: "users/passwords",
    registrations: "users/registrations"
  }
  # Administrative user paths.
  namespace :admin do
    resources :users, only: [:index, :new, :create, :edit, :update, :show]
  end

  get "up" => "rails/health#show", :as => :rails_health_check

  resources :sites do
    resources :documents do
      member do
        patch :update_status
        get :modal_content
      end
      collection do
        patch :batch_update
        get :insights
        get :audit_exports
      end
    end
  end

  resources :documents, only: [] do
    member do
      patch :update_document_category
      patch :update_accessibility_recommendation
      patch :update_notes
      patch :update_summary_inference
      patch :update_recommendation_inference
      get "serve_content/:filename", to: "documents#serve_document_url", as: "serve_file_content", constraints: {filename: /[^\/]+/}
    end
  end

  mount Sidekiq::Web => "/sidekiq"

  mount AsapPdf::API => "/api"
  get "api-docs", to: "api_docs#index"

  resource :configuration, only: [:edit, :update]

  root "sites#index"
end
