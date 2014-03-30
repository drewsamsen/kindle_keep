require 'sinatra'
require 'sinatra-initializers'
require 'singleton'

register Sinatra::Initializers

get '/' do
  haml :index
end

post '/connect' do
  email, pass = params[:email], params[:password]

  if email.empty? || pass.empty?
    redirect '/?error=true'
  end

  Thread.new do
    kindle = KindleKeep.instance
    if kindle.connect(email, pass)
      kindle.log_in
      kindle.get_highlights if kindle.login_successful?
    end
  end

  redirect '/fetching'
end

get '/fetching' do
  "Fetching Kindle highlights..."
end

require_relative 'kindle_keep'