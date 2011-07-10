%w(java tmpdir girl_friday safe_queue spoon redis json user fileutils hoptoad_notifier).each do |lib|
  require lib
end

require 'citrus/grammars'
Citrus.require('email')

require 'extractor/readability_api'

class Async
  Config = JSON.parse(File.read('config/config.json'))

  attr_reader :extractor, :error

  # TODO: Cleanup
  def initialize
    @tmp = Dir.tmpdir
    @redis = Redis.new
    # Send errors to Loggly
    @error = GirlFriday::WorkQueue.new(:error, &method(:error_handler))
    # Cleanup files after they are no longer needed
    @cleanup = GirlFriday::WorkQueue.new(:cleanup, &method(:cleanup))
    # Send emails
    @emails = SafeQueue.build(:email, &method(:send_email))
    # Run kindlegen
    @kindlegen = SafeQueue.build(:kindlegen, &method(:run_kindlegen))
    # Run pandoc
    @pandoc = SafeQueue.build(:pandoc, &method(:run_pandoc))
    # Run extraction
    @extractor = SafeQueue.build(:extractor, &method(:run_extractor))
  end

private

  def extension_swap(path, after)
    path.gsub(/[^.]+$/, after)
  end

  def write_epub_xml(epub, title, author)
    xml = extension_swap(epub, 'xml')
    File.open(xml, 'w') do |f|
      f.write("<dc:title>#{title}</dc:title>\n<dc:creator>#{author}</dc:creator>\n")
    end
    xml
  end

  def cleanup(directory)
    FileUtils.rm_rf(directory) if File.exists?(directory)
  end

  def error_handler(message)
    error, directory = message.values_at(:error, :working)
    @cleanup << directory
    Loggly.error(error)
  end

  def send_email(message)
    key, email, url, title, mobi, working = message.values_at(:key, :email, :url, :title, :mobi, :working)
    begin
      EmailAddress.parse(email)
    rescue Citrus::ParseError
      @error << { error: "The email '#{email}' failed to validate!", working: working }
      User.notify(@redis, key, 'Your email appears invalid. Try carefully remaking the bookmarklet.')
    else
      User.mail(email, title, url, mobi)
      User.notify(@redis, key, 'All done! Grab your Kindle and hang tight!')
      @cleanup << working
    end
  end

  def run_kindlegen(message)
    key, html, title, working, epub, url = message.values_at(:key, :html, :title, :working, :epub, :url)
    mobi = extension_swap(epub, 'mobi')
    pid = Spoon.spawnp('kindlegen', epub)
    _, status = Process.waitpid2(pid)
    # Will probably run with warnings, and return 1 instead
    if File.exists?(mobi)
      User.notify(@redis, key, 'Third stage finished...')
      message.merge!(mobi: mobi)
      @emails << message
    else
      @error << { error: "kindlegen blew up on #{url}", working: working }
      User.notify(@redis, key, 'Third stage failed. Developer notified.')
    end
  end

  def run_pandoc(message)
    key, html, title, author, working, url = message.values_at(:key, :html, :title, :author, :working, :url)
    epub = extension_swap(html, 'epub')
    xml = write_epub_xml(epub, title, author)
    pid = Spoon.spawnp('pandoc', '--epub-metadata', xml, '-o', epub, html)
    _, status = Process.waitpid2(pid)
    if status.success?
      User.notify(@redis, key, 'Second stage finished...')
      message.merge!(epub: epub)
      @kindlegen << message
    else
      @error << { error: "pandoc blew up on #{url}", working: working }
      User.notify(@redis, key, 'Second stage failed. Developer notified.')
    end
  end

  def run_extractor(message)
    key, url = message.values_at(:key, :url)
    working = File.join(@tmp, key)
    ex = Extractor::ReadabilityApi.new(url, working)
    begin
      outfile, title, author = ex.extract!
      User.notify(@redis, key, 'First stage finished...')
      message.merge!(html: outfile, title: title, author: author, working: working)
      @pandoc << message
    rescue Exception => boom
      HoptoadNotifier.notify_or_ignore(boom)
      @error << { error: "Failed extracting URL: #{url}", working: working }
      User.notify(@redis, key, 'Failed extracting this page. Developer notified.')
    end
  end
end
