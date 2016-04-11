Rails.application.routes.draw do

  get '/addcontact' => 'add_contact#AddContact'
  post '/actions/file_upload' => 'actions#file_upload'
  get '/actions/attachments' => 'actions#attachments'
  get '/actions/records' => 'actions#all_records'
  post '/actions/get_records' => 'actions#get_records'
  get '/app2app/start' => 'app2app#start'
  post '/app2app/transfer' => 'app2app#transfer'
  get '/actions/attachments_no_zip' => 'actions#attachments_no_zip'
  post '/actions/file_upload_no_zip' => 'actions#file_upload_no_zip'
  get '/actions/appsettings' => 'actions#appsettings'
  get '/actions/api_test' => 'actions#api_test'
  get '/actions/delete_actions' => 'actions#delete_actions'

  get '/actions/basecamp' => 'actions#basecamp'
  get '/actions/closeio' => 'actions#closeio'
  get '/actions/closeio_json2csv' => 'actions#closeio_json2csv'

  get '/json2csv/start' => 'json2csv#start'
  post '/json2csv/convert' => 'json2csv#convert'

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
