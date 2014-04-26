require 'sinatra'
require 'sinatra-initializers'

register Sinatra::Initializers

get '/' do
  haml :index
end

post '/connect' do
  file  = params[:file].empty? ? nil : params[:file]
  email = params[:email]
  pass  = params[:password]
  limit = params[:limit].empty? ? 9999999 : params[:limit].to_i

  unless file || (email && pass)
    redirect '/?error=true'
  end

  Thread.new do
    kindle = KindleKeep.instance
    if kindle.connect(email, pass, file)
      kindle.log_in unless file
      kindle.get_highlights(limit)
      kindle.write_highlights_to_file
    end
  end

  redirect '/fetching'
end

get '/fetching' do
  "Fetching Kindle highlights..."
end

require_relative 'kindle_keep'