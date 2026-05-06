Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
  mount MissionControl::Jobs::Engine, at: "/jobs"

  resources :theses, only: [ :index, :show, :new, :create, :edit, :update ] do
    resources :chapters, only: [ :destroy ]
    member do
      post :approve_outline
      post :start_research
      post :start_drafting
      post :start_verification
      post :add_chapter
      post :confirm_facts
      get  :download_pdf
    end
  end

  root "theses#index"
end
