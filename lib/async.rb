require 'tmpdir'
require 'girl_friday'
require 'spoon'
require 'redis'
require 'postmark'
require 'mail'
require 'json'

class Async
  Config = JSON.parse(File.read('config/config.json'))

  attr_reader :extractor, :pandoc, :kindlegen, :email, :error

  # TODO: Cleanup
  def initialize
    async = self
    tmp = Dir.tmpdir

    @extractor = GirlFriday::WorkQueue.new(:extractor) do |message|
      email, url, key = message.values_at(:email, :url, :key)
      out = File.join(tmp, "#{key}.html")
      File.open(out, 'w') do |f|
        f.write(File.read('test.html'))
      end
      Async.notify(Redis.new, key, 'First stage finished.')
      message.merge!(html: out, title: 'Compiler')
      async.pandoc << message
    end

    @pandoc = GirlFriday::WorkQueue.new(:pandoc) do |message|
      email, url, key, html, title = message.values_at(:email, :url, :key, :html, :title)
      dir = File.dirname(html)
      xml = File.join(dir, "#{key}.xml")
      File.open(xml, 'w') do |f|
        f.write("<dc:title>#{title}</dc:title>")
      end
      epub = File.join(dir, "#{key}.epub")
      pid = Spoon.spawnp('pandoc', '--epub-metadata', xml, '-o', epub, html)
      _, status = Process.waitpid2(pid)
      if status.success?
        Async.notify(Redis.new, key, 'Second stage finished.')
        message.merge!(epub: epub)
        async.kindlegen << message
      else
        Async.notify(Redis.new, key, 'Second stage failed. Developer notified.')
      end
    end

    @kindlegen = GirlFriday::WorkQueue.new(:kindlegen) do |message|
      redis = Redis.new
      email, url, key, html, title, epub = message.values_at(:email, :url, :key, :html, :title, :epub)
      mobi = File.join(File.dirname(html), "#{key}.mobi")
      pid = Spoon.spawnp('kindlegen', epub)
      _, status = Process.waitpid2(pid)
      # Will probably run with warnings, and return 1 instead
      if File.exists?(mobi)
        Async.notify(Redis.new, key, 'Third stage finished.')
        message.merge!(mobi: mobi)
        async.email << message
      else
        Async.notify(Redis.new, key, 'Third stage failed. Developer notified.')
      end
    end

    @email = GirlFriday::WorkQueue.new(:email) do |message|
      email, url, key, html, title, epub, mobi = message.values_at(:email, :url, :key, :html, :title, :epub, :mobi)
      m = Mail.new
      m.delivery_method(Mail::Postmark, api_key: Config['postmark'])
      m.from Config['email']['from']
      m.to email
      m.subject 'convert'
      m.body "Straight to your Kindle! #{title}: #{url}"
      m.postmark_attachments = [File.open(mobi)]
      m.deliver!
      Async.notify(Redis.new, key, 'All done!')
    end

    @error = GirlFriday::WorkQueue.new(:error) do |message|
      Loggly.error(message)
    end
  end

  class << self
    def notify(redis, key, message)
      redis.multi do
        redis.set(key, message)
        redis.expire(key, 30)
      end
    end
  end
end
