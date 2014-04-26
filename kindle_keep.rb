require 'json'
require 'digest/md5'
require 'pry'

# =================================================
# Class: Connects to amazon kindle, gets highlights
# =================================================
class KindleKeep
  include Singleton

  def connect(email, pass)
    @email, @pass = email, pass
    @highlights   = Array.new
    @books        = Hash.new
    new_session
    @session.visit(KINDLE_HOME)
    save_html_as_instance_variable
    @start_time = Time.now
    @highlight_count = 0
    @timer = 0
    @limit = 0
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
      log_with_timestamp("submiting login form")
      find('#signInSubmit').click
      log_with_timestamp("Logging in")
    end

    # Check if authentication was a success
    log_with_timestamp(login_successful? ? "You're in! authenticated." : "ERROR: Authentication failed")
    log_current_path
    save_html_as_instance_variable
  end

  def get_highlights(limit)
    log_with_timestamp("lets get some highlights, bitches!!!1")
    click_link "Your Highlights"

    title = String.new
    author = String.new
    count = 0
    new_count = 0
    @limit = limit

    log_current_path if has_selector?(:css, "#allHighlightedBooks")

    scroll_to_bottom

    log_with_timestamp("Processing page... (this may take a minute)")

    # Each row can be a heading marking the start of a new book, or it can
    # be a highlight. So as we progress down the rows we need to keep track
    # of the current book for each highlight.
    all(:css, "#allHighlightedBooks > div").each do |row|
      if is_book_title?(row)
        title = row.find(:css, ".title").text
        @books[title] = Array.new
        author = row.find(:css, ".author").text.gsub(/^by /,'')
      elsif is_highlight?(row)
        body = row.find(:css, ".highlight").text

        # Create a unique id for this highlight
        guid = Digest::MD5.hexdigest(body)

        @books[title] << {
          :title => title,
          :author => author,
          :highlight => body,
          :guid => guid
        }

        count = count + 1
        log_with_timestamp("processed #{count}/#{@highlight_count}")
      end
      break if count >= @limit
    end
    log_with_timestamp("Total highlights found: #{count.to_s}")
    # show_highlights
    write_highlights_to_file
    # write_summary_file
  end

  def log_with_timestamp(msg)
    puts "T+#{(Time.now - @start_time).to_int}s: #{msg}"
  end

  def write_highlights_to_file
    Dir.mkdir("highlights") unless directory_already_exists_at("highlights")

    @books.each do |title, highlights|

      log_with_timestamp("=========\nWriting highlights for '#{title}'")

      filename = "highlights/#{title}.json"

      if file_exists?(filename)
        existing = JSON.parse( IO.read(filename) )
        highlights = remove_highlights_that_are_already_in_file(existing, highlights)
      else
        existing = []
      end

      log_with_timestamp("Adding #{highlights.size} highlights to '#{title}'")

      File.open(filename, 'w') do |file|
        file.write(JSON.pretty_generate(existing + highlights))
      end

    end
  end

  def remove_highlights_that_are_already_in_file(existing, highlights)
    existing_guids = existing.collect {|hl| hl['guid']}
    highlights.delete_if { |high| existing_guids.include?(high['guid']) }
  end

  def write_summary_file
    summary = {
      total: @highlights.size,
      books: Array.new
    }
    @books.each do |title, highlights|
      summary.books << {
        title: title,
        highlights: highlights.size
      }
    end
    File.open("highlights/summary.json", 'w') do |file|
      file.write(JSON.pretty_generate(summary))
    end
  end

  def directory_already_exists_at(path)
    File.exists?(path) && File.directory?(path)
  end

  def file_exists?(file)
    File.exists?(file)
  end

  def scroll_to_bottom
    update_highlight_count
    scroll_down
    while under_limit? && timer_less_than(20) do
      timer_tick
      if new_highlights?
        update_highlight_count
        log_with_timestamp("new highlights detected (#{@highlight_count}/#{@limit})\nresetting timer and scrolling down...")
        reset_timer
        scroll_down
      end
      unless under_limit?
        log_with_timestamp("LIMIT REACHED")
      end
    end
    log_with_timestamp("\n==========\nDone.\n==========\n")
  end

  def under_limit?
    @highlight_count < @limit
  end

  def update_highlight_count
    @highlight_count = get_highlight_count
  end

  def new_highlights?
    @highlight_count != get_highlight_count
  end

  def timer_less_than(limit)
    @timer < limit
  end

  def timer_tick
    @timer = @timer + 1
    sleep 1
    puts "tick: #{@timer}"
  end

  def reset_timer
    @timer = 0
  end

  def scroll_down
    execute_script('window.scrollTo(0,document.body.scrollHeight)')
  end

  # Takes the text of the last highlight on the page and hashes it. We can use
  # this to compare highlights and determine when new highlights are added to
  # the end of the page.
  def get_highlight_count
    all(:css, ".highlight").count
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
    log_with_timestamp("#{@session.current_url}")
  end

end