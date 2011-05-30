%w(java tmpdir girl_friday safe_queue spoon redis json user fileutils hoptoad_notifier).each do |lib|
  require lib
end

# require 'extractor/goose'
# require 'extractor/scala_readability'
require 'extractor/readability_api'

class Async
  Config = JSON.parse(File.read('config/config.json'))

  attr_reader :extractor, :error

  # TODO: Cleanup
  def initialize
    tmp = Dir.tmpdir
    redis = Redis.new

    # Cleanup files after they are no longer needed
    cleanup_queue = GirlFriday::WorkQueue.new(:cleanup) do |directory|
      FileUtils.rm_rf(directory)
    end

    # Send errors to Loggly
    error_queue = @error = GirlFriday::WorkQueue.new(:error) do |message|
      error, directory = message.values_at(:error, :working)
      cleanup_queue << directory
      Loggly.error(error)
    end

    # Send emails
    email_queue = SafeQueue.build(:email) do |message|
      email, url, key, title, mobi = message.values_at(:email, :url, :key, :title, :mobi)
      User.mail(email, title, url, mobi)
      User.notify(redis, key, 'All done! Grab your Kindle and hang tight!')
    end

    # Run kindlegen
    kindlegen_queue = SafeQueue.build(:kindlegen) do |message|
      email, url, key, html, title, working, epub = message.values_at(:email, :url, :key, :html, :title, :working, :epub)
      mobi = File.join(working, 'out.mobi')
      pid = Spoon.spawnp('kindlegen', epub)
      _, status = Process.waitpid2(pid)
      # Will probably run with warnings, and return 1 instead
      if File.exists?(mobi)
        User.notify(redis, key, 'Third stage finished...')
        message.merge!(mobi: mobi)
        email_queue << message
      else
        error_queue << { error: "kindlegen blew up on #{url}", working: working }
        User.notify(redis, key, 'Third stage failed. Developer notified.')
      end
    end

    write_epub_xml = proc do |working, title, author|
      xml = File.join(working, 'out.xml')
      File.open(xml, 'w') do |f|
        f.write("<dc:title>#{title}</dc:title>\n<dc:author>#{author}</dc:author>")
      end
      xml
    end

    # Run pandoc
    pandoc_queue = SafeQueue.build(:pandoc) do |message|
      email, url, key, html, title, author, working = message.values_at(:email, :url, :key, :html, :title, :author, :working)
      xml = write_epub_xml.call(working, title, author)
      epub = File.join(working, 'out.epub')
      pid = Spoon.spawnp('pandoc', '--epub-metadata', xml, '-o', epub, html)
      _, status = Process.waitpid2(pid)
      if status.success?
        User.notify(redis, key, 'Second stage finished...')
        message.merge!(epub: epub)
        kindlegen_queue << message
      else
        error_queue << { error: "pandoc blew up on #{url}", working: working }
        User.notify(redis, key, 'Second stage failed. Developer notified.')
      end
    end

    # Run extraction
    @extractor = SafeQueue.build(:extractor) do |message|
      email, url, key = message.values_at(:email, :url, :key)
      working = File.join(tmp, key)
      ex = Extractor::ReadabilityApi.new(url, working)
      begin
        outfile, title, author = ex.extract!
        User.notify(redis, key, 'First stage finished...')
        message.merge!(html: outfile, title: title, author: author, working: working)
        pandoc_queue << message
      rescue Extractor::ExtractionFailedException => boom
        HoptoadNotifier.notify_or_ignore(boom)
        error_queue << { error: "Failed extracting URL: #{url}", working: working }
        User.notify(redis, key, 'Failed extracting this page. Developer notified.')
      end
    end
  end
end
