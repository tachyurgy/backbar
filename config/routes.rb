Rails.application.routes.draw do
  root "board#index"
  get "sku/:code", to: "board#sku", as: :sku
  resources :counts, only: [:index, :create]
  post "counts/:id/post", to: "counts#post_now", as: :post_count
  get "up" => "rails/health#show", as: :rails_health_check
end
