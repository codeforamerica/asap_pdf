Rails.application.routes.draw do
  get "up" => "rails/health#show", :as => :rails_health_check

  resource :session
  get "login", to: "sessions#new", as: :login

  resources :dashboard, only: [:index] do
    collection do
      post :upload_pdf
    end
  end

  resources :sites do
    resources :documents do
      member do
        patch :update_status
        get :modal_content
      end
      collection do
        patch :batch_update
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

  mount AsapPdf::API => "/api"
  get "api-docs", to: "api_docs#index"

  resource :configuration, only: [:edit, :update]

  root "sites#index"
end
