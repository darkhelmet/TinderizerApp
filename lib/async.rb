%w(java tmpdir girl_friday safe_queue spoon redis json user fileutils hoptoad_notifier blacklist).each do |lib|
  require lib
end

require 'citrus/grammars'
Citrus.require('email')
Citrus.require('uri')

require 'extractor/readability_api'

class Async
  class UrlInvalidException < StandardError; end

  module ReadabilityFailed
    def ===(boom)
      if json = boom.respond_to?(:response) and !boom.response.empty? and JSON.parse(boom.response)
        json['message'] =~ /^Could not parse the content/
      end
    end
  end

  module ReadabilityError
    def ===(boom)
      if json = boom.respond_to?(:response) and !boom.response.empty? and JSON.parse(boom.response)
        json['message'] =~ /^Readability encountered a server error/
      end
    end
  end

  Config = JSON.parse(File.read('config/config.json'))

  attr_reader :extractor, :error

  # TODO: Cleanup
  def initialize
    @tmp = Dir.tmpdir
    # @tmp = File.expand_path('tmp')
    @redis = Redis.new
    # Send errors to Loggly
    @error = GirlFriday::WorkQueue.new(:error, &method(:error_handler))
    # Cleanup files after they are no longer needed
    @cleanup = GirlFriday::WorkQueue.new(:cleanup, &method(:cleanup))
    # Send emails
    @emails = SafeQueue.build(:email, &method(:send_email))
    # Run kindlegen
    @kindlegen = SafeQueue.build(:kindlegen, &method(:run_kindlegen))
    # Run extraction
    @extractor = SafeQueue.build(:extractor, &method(:run_extractor))
  end

private

  def extension_swap(path, after)
    path.gsub(/[^.]+$/, after)
  end

  def notify(key, message)
    User.notify(@redis, key, message)
  end

  def error(message, working, severity = :error)
    @error << { error: message, working: working, severity: severity }
  end

  def cleanup(directory)
    FileUtils.rm_rf(directory) if File.exists?(directory)
  end

  def error_handler(message)
    error, directory = message.values_at(:error, :working)
    @cleanup << directory
    Loggly.send(message.fetch(:severity, :error), error)
  end

  def send_email(message)
    key, email, url, title, mobi, working = message.values_at(:key, :email, :url, :title, :mobi, :working)
    begin
      EmailAddress.parse(email)
    rescue Citrus::ParseError
      error("The email '#{email}' failed to validate!", working, :notice)
      notify(key, 'Your email appears invalid. Try carefully remaking the bookmarklet.')
    else
      User.mail(email, title, url, mobi)
      notify(key, 'All done! Grab your Kindle and hang tight!')
      @cleanup << working
    end
  end

  def run_kindlegen(message)
    key, html, title, author, working, html, url = message.values_at(:key, :html, :title, :author, :working, :html, :url)
    mobi = extension_swap(html, 'mobi')
    pid = Spoon.spawnp('kindlegen', html)
    _, status = Process.waitpid2(pid)
    # Will probably run with warnings, and return 1 instead
    if File.exists?(mobi)
      notify(key, 'Second stage finished...')
      message.merge!(mobi: mobi)
      @emails << message
    else
      error("kindlegen blew up on #{url}", working)
      notify(key, 'Second stage failed. Developer notified.')
    end
  end

  def run_extractor(message)
    key, url = message.values_at(:key, :url)
    working = File.join(@tmp, key)
    ex = Extractor::ReadabilityApi.new(url, working)
    begin
      uri = UniformResourceIdentifier.parse(url)
      raise UrlInvalidException, "'#{uri.scheme}' is an invalid scheme" unless uri.scheme.to_s =~ /https?/i
      outfile, title, author = ex.extract!
      notify(key, 'First stage finished...')
      message.merge!(html: outfile, title: title, author: author, working: working)
      @kindlegen << message
    rescue Citrus::ParseError, UrlInvalidException
      Blacklist.blacklist!(@redis, url)
      error("The URL(#{url}) is not valid for extraction", working, :notice)
      notify(key, 'This URL appears invalid. Sorry :(')
    rescue ReadabilityFailed, Extractor::BlacklistError
      Blacklist.blacklist!(@redis, url)
      notify(key, 'Readability failed extracting this URL.')
      cleanup(working)
    rescue ReadabilityError
      notify(key, 'Readability had an error, try again in a few mintues.')
      cleanup(working)
    rescue RestClient::ExceptionWithResponse => failed_request
      error("Failed extracting URL(#{url}) with response: #{failed_request.response}", working)
      notify(key, 'Failed extracting this page. Developer notified.')
    rescue Exception => boom
      HoptoadNotifier.notify_or_ignore(boom)
      error("Failed extracting URL(#{url}) with error: #{boom.message}", working)
      notify(key, 'Failed extracting this page. Developer notified.')
    end
  end
end
