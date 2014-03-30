require 'sinatra'
require 'sinatra-initializers'
require 'singleton'

register Sinatra::Initializers

get '/' do
  haml :index
end

post '/connect' do
  email = params[:email]
  pass  = params[:password]

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


# =================================================
# Class: Connects to amazon kindle, gets highlights
# =================================================
class KindleKeep
  include Singleton

  def connect(email, pass)
    @email, @pass = email, pass
    new_session
    @session.visit(KINDLE_HOME)
    save_html_as_instance_variable
  end

  def log_in

    log_current_path

    find("#sidepanelSignInButton a").click

    log_current_path if has_content?('What is your e-mail address?')

    # Log in
    if has_selector?(:css, '#ap_signin_form')
      find(:css, '#ap_email').set(@email)
      choose("ap_signin_existing_radio")
      find(:css, '#ap_password').set(@pass)
      puts "submit"
      find('#signInSubmit').click
      puts "Logging in..."
    end

    # Check if authentication was a success
    puts login_successful? ? "You're in! authenticated." : "ERROR: Authentication failed"
    log_current_path
    save_html_as_instance_variable
  end

  def get_highlights
    puts "lets get some highlights, bitches!!!1\n"
    click_link "Your Highlights"

    title = String.new
    author = String.new
    highlight = Hash.new
    count = 0

    log_current_path if has_selector?(:css, "#allHighlightedBooks")

    scroll_to_bottom

    # Each row can be a heading marking the start of a new book, or it can
    # be a highlight. So as we progress down the rows we need to keep track
    # of the current book for each highlight.
    all(:css, "#allHighlightedBooks > div").each do |row|
      if is_book_title?(row)
        title = row.find(:css, ".title").text
        author = row.find(:css, ".author").text
      elsif is_highlight?(row)
        highlight[:title] = title
        highlight[:author] = author
        highlight[:highlight] = row.find(:css, ".highlight").text
        count = count + 1
        puts "#{ highlight[:highlight] }\n"
        puts "- #{highlight[:title]}, #{highlight[:author]}\n\n"
      end
    end
    puts "\n\nTotal highlights found: #{count.to_s}\n\n"
  end

  def scroll_to_bottom
    item_count = all(:css, ".highlight").count
    new_count = 0
    puts "found #{item_count} items"

    begin
      item_count = all(:css, ".highlight").count
      puts "scrolling down..."
      execute_script('window.scrollTo(0,document.body.scrollHeight)')
      new_count = wait_for_new_highlights_to_load(item_count)
    end while new_count > item_count

    puts "\n==========\nDone. Found #{item_count} items total.\n==========\n"
  end

  # Check to see if new highlights loaded every second. Break when the new
  # highlights load of 10 seconds pass.
  def wait_for_new_highlights_to_load(item_count)
    new_count = 0
    t = 0
    begin
      sleep 1
      t = t + 1
      new_count = all(:css, ".highlight").count
      if new_count > item_count
        puts "Found #{new_count - item_count} new items. #{new_count} total.\n"
      end
    end while new_count == item_count && t < 10
    new_count
  end

  def is_book_title?(row)
    row[:class].match(/yourHighlightsHeader/)
  end

  def is_highlight?(row)
    row[:class].match(/yourHighlight/)
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

  def log_current_path
    puts "#{@session.current_url}\n"
  end

end