require 'sinatra'
require 'sinatra-initializers'

register Sinatra::Initializers

get '/' do
  haml :index
end

get '/connect' do
  if kindle = KindleKeep.new(EMAIL, PASS)
    kindle.log_in
    kindle.get_highlights if kindle.login_successful?
  end
  redirect '/success'
end

get '/success' do
  "Success!"
end


# =================================================
# Class: Connects to amazon kindle, gets highlights
# =================================================
class KindleKeep

  def initialize(email, pass)
    @email, @pass = email, pass
    new_session
    @session.visit(KINDLE_HOME)
    save_html_as_instance_variable
  end

  def log_in

    find("#sidepanelSignInButton a").click

    if has_content?('What is your e-mail address?')
      puts "on login page..."
    else
      puts "WARNING: not on the login page as expected..."
    end

    # Log in
    if has_selector?(:css, '#ap_signin_form')
      puts "login form located..."
      puts "fill in name"
      find(:css, '#ap_email').set(@email)
      puts "select radio"
      choose("ap_signin_existing_radio")
      puts "password"
      find(:css, '#ap_password').set(@pass)
      puts "submit"
      find('#signInSubmit').click
    end

    # Check if authentication was a success
    puts login_successful? ? "You're in! authenticated." : "ERROR: Authentication failed"
    save_html_as_instance_variable
  end

  def get_highlights
    puts "lets get some highlights, bitches!!!1"
  end

  # To save ourselves calling each of the capybara methods on the instance
  # variable, @session, we use method_missing trick. #soMeta
  def method_missing(sym, *args, &block)
    if @session.respond_to?(sym)
      @session.send(sym, *args, &block)
    else
      super(sym, *args, &block)
    end
  end

  def login_successful?
    error_text    = 'There was a problem with your request'
    success_text  = 'Your Highlights'
    !has_content?(error_text) && has_content?(success_text)
  end

private

  # Create a new PhantomJS session in Capybara
  def new_session

    # Register PhantomJS (aka poltergeist) as the driver to use
    Capybara.register_driver :poltergeist do |app|
      Capybara::Poltergeist::Driver.new(app, :phantomjs => Phantomjs.path)
    end

    # Use XPath as the default selector for the find method
    Capybara.default_selector = :css

    # Start up a new thread
    @session = Capybara::Session.new(:poltergeist)

    # Report using a particular user agent
    @session.driver.headers = { 'User-Agent' => "Mozilla/5.0 (Macintosh; Intel Mac OS X)" }

    # Return the driver's session
    @session
  end

  # Returns the current session's page
  def html
    @session.html
  end

  def save_html_as_instance_variable
    @page = Nokogiri::HTML.parse(html)
  end

end