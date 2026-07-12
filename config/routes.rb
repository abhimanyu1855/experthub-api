Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  devise_for :users, path: '', path_names: {
    sign_in: 'login',
    sign_out: 'logout',
    registration: 'signup'
  },
  controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations'
  }

  resource :tenant, only: [:show, :update]
  resources :tenants, only: [:create]
  get 'me', to: 'users#me'
  patch 'me', to: 'users#update'



  get 'services/:service_id/slots', to: 'availability#index'

  resources :bookings, only: [:index, :show, :create] do
    member do
      post :confirm
      post :cancel
      patch :transcript, to: 'bookings#update_transcript'
      post :transcript, to: 'bookings#update_transcript'
      post :marketing_post
      post :reschedule_requests, to: 'reschedule_requests#create'
    end
  end

  post 'webhooks/stripe', to: 'webhooks#stripe'
  post 'webhooks/razorpay', to: 'webhooks#razorpay'
  post 'webhooks/paypal', to: 'webhooks#paypal'
  post 'webhooks/payfast', to: 'webhooks#payfast'

  # Platform billing — charges operators for their ExpertHub plan
  post 'billing/checkout', to: 'billing#checkout'
  post 'billing/webhook',  to: 'billing#webhook'

  get 'referrals/summary', to: 'referrals#summary'

  resources :services, only: [:index, :show, :create, :update, :destroy] do
    resources :reviews, only: [:index, :create]
  end

  resources :reviews, only: [:index]

  resources :reschedule_requests, only: [] do
    member do
      post :accept
      post :reject
    end
  end

  resources :conversations, only: [:index, :create] do
    resources :messages, only: [:index, :create]
  end

  get 'notifications/unread_count', to: 'notifications#unread_count'
  resources :notifications, only: [:index] do
    member do
      post :read
    end
  end

  resources :courses, only: [:index, :show, :create, :update] do
    member do
      post :enroll
    end
  end

  resources :lessons, only: [:create] do
    member do
      post :complete
      get :quiz
      post 'quiz/submit', to: 'lessons#submit_quiz'
    end
  end

  resources :group_sessions, only: [:index, :show, :create] do
    member do
      post :register
    end
  end

  resources :booking_packages, only: [:index, :create] do
    member do
      post :purchase
    end
  end

  resources :subscription_plans, only: [:index, :create, :update]
  resources :subscriptions, only: [:index, :create] do
    member do
      post :cancel
    end
  end

  resources :promo_codes, only: [:index, :create, :destroy]
  post 'promo_codes/validate', to: 'promo_codes#validate'
  resources :pages, only: [:show], param: :slug
  resources :checkout_fields, only: [:index, :create, :destroy]

  get 'analytics/dashboard', to: 'analytics#dashboard'
  get 'analytics/expert', to: 'analytics#expert'

  resource :cancellation_policy, only: [:show, :create, :update]

  resources :payment_configs, only: [:index, :create]
  resources :categories, only: [:index, :create, :update, :destroy]


  namespace :ai do
    post :match, to: 'match#match'
    post :triage_sessions, to: 'triage#create'
    post 'triage_sessions/:session_token/chat', to: 'triage#chat'
  end

  namespace :admin do
    get 'onboarding_status', to: 'onboarding_status#show'
    patch 'onboarding_status/:step_id', to: 'onboarding_status#update'
    resources :users, only: [:index, :update]
    resources :expert_applications, only: [:index] do
      member do
        post :approve
        post :reject
      end
    end
  end

  resources :working_time_slots, only: [:index, :create, :destroy]
  resources :expert_applications, only: [:create]
  post 'experts/stripe_account', to: 'experts#stripe_account'
  post 'experts/stripe_onboarding_link', to: 'experts#stripe_onboarding_link'
  resources :experts, only: [:index, :show]
  patch 'experts/profile', to: 'experts#update_profile'
  get "up" => "rails/health#show", as: :rails_health_check
  # Render and some load balancers probe HEAD / — API has no HTML root.
  match "/", to: redirect("/up"), via: [:get, :head]

  mount ActionCable.server => "/cable"
end
