Rails.application.routes.draw do
  get '/favicon.ico', to: ->(_env) { [204, {}, []] }
end
