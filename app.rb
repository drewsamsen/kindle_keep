require 'sinatra'
require 'sinatra-initializers'

register Sinatra::Initializers

get '/' do
  haml :index
end

post '/connect' do
  email = params[:email]
  pass  = params[:password]
  limit = params[:limit].empty? ? 9999999 : params[:limit].to_i

  if email.empty? || pass.empty?
    redirect '/?error=true'
  end

  Thread.new do
    kindle = KindleKeep.instance
    if kindle.connect(email, pass)
      kindle.log_in
      kindle.get_highlights(limit) if kindle.login_successful?
    end
  end

  redirect '/fetching'
end

get '/fetching' do
  "Fetching Kindle highlights..."
end

require_relative 'kindle_keep'