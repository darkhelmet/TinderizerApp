require 'java'
require 'tmpdir'
require 'girl_friday'
require 'safe_queue'
require 'spoon'
require 'redis'
require 'postmark'
require 'mail'
require 'json'
require 'user'
require 'image_monster'
require 'goose_extractor'
require 'readability_extractor'

class Async
  Config = JSON.parse(File.read('config/config.json'))

  attr_reader :extractor, :error

  # TODO: Cleanup
  def initialize
    tmp = Dir.tmpdir
    redis = Redis.new

    error_queue = @error = GirlFriday::WorkQueue.new(:error) do |message|
      Loggly.error(message)
    end

    email_queue = SafeQueue.build(:email) do |message|
      email, url, key, html, title, epub, mobi = message.values_at(:email, :url, :key, :html, :title, :epub, :mobi)
      m = Mail.new
      m.delivery_method(Mail::Postmark, api_key: Config['postmark'])
      m.from Config['email']['from']
      m.to email
      m.subject 'convert'
      m.body "Straight to your Kindle! #{title}: #{url}"
      m.postmark_attachments = [File.open(mobi)]
      m.deliver!
      User.notify(redis, key, 'All done! Grab your Kindle and hang tight!')
    end

    kindlegen_queue = SafeQueue.build(:kindlegen) do |message|
      email, url, key, html, title, epub = message.values_at(:email, :url, :key, :html, :title, :epub)
      mobi = File.join(File.dirname(html), "#{key}.mobi")
      pid = Spoon.spawnp('kindlegen', epub)
      _, status = Process.waitpid2(pid)
      # Will probably run with warnings, and return 1 instead
      if File.exists?(mobi)
        User.notify(redis, key, 'Third stage finished.')
        message.merge!(mobi: mobi)
        email_queue << message
      else
        error_queue << "kindlegen blew up on #{url}"
        User.notify(redis, key, 'Third stage failed. Developer notified.')
      end
    end

    pandoc_queue = SafeQueue.build(:pandoc) do |message|
      email, url, key, html, title = message.values_at(:email, :url, :key, :html, :title)
      dir = File.dirname(html)
      xml = File.join(dir, "#{key}.xml")
      File.open(xml, 'w') { |f| f.write("<dc:title>#{title}</dc:title>") }
      epub = File.join(dir, "#{key}.epub")
      pid = Spoon.spawnp('pandoc', '--epub-metadata', xml, '-o', epub, html)
      _, status = Process.waitpid2(pid)
      if status.success?
        User.notify(redis, key, 'Second stage finished.')
        message.merge!(epub: epub)
        kindlegen_queue << message
      else
        error_queue << "pandoc blew up on #{url}"
        User.notify(redis, key, 'Second stage failed. Developer notified.')
      end
    end

    @extractor = SafeQueue.build(:extractor) do |message|
      email, url, key = message.values_at(:email, :url, :key)
      working = File.join(tmp, key)
      Dir.mkdir(working)
      # ex = ReadabilityExtractor.new(url, working)
      ex = GooseExtractor.new(url, working)
      outfile, title, image_map = ex.extract!
      # User.notify(redis, key, 'Failed extracting this page. Developer notified.')
      # error_queue << "Failed extracting URL: #{url}"
      ImageMonster.eat(image_map, working)
      User.notify(redis, key, 'First stage finished.')
      message.merge!(html: outfile, title: title, working: working)
      pandoc_queue << message
    end
  end
end
