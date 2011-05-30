require 'redis'
require 'mail'
require 'json'
require 'postmark'

module User
  Config = JSON.parse(File.read('config/config.json'))
  Lua = <<-LUA
    local value = redis('get', KEYS[1])
    if value ~= nil then return {err='limited'} end
    redis('set', KEYS[1], 'locked')
    redis('expire', KEYS[1], tonumber(ARGV[1]))
    return {ok='locked'}
  LUA

  class << self
    def mail(email, title, url, mobi)
      m = Mail.new
      m.delivery_method(Mail::Postmark, api_key: Config['postmark'])
      m.from Config['email']['from']
      m.to email
      m.subject 'convert'
      m.body "Straight to your Kindle! #{title}: #{url}"
      m.postmark_attachments = [File.open(mobi)]
      m.deliver!
    end

    def notify(redis, key, message)
      redis.multi do
        redis.set(key, message)
        redis.expire(key, 30)
      end
    end

    def limit(redis, email, time)
      begin
        redis.eval(Lua, 1, Digest::SHA1.hexdigest(email), time)
      rescue RuntimeError => limited
        return {
          message: "Sorry, but there's a rate-limit, and you've hit it! Try again in a minute.",
          limited: true
        }.to_json
      end
      yield
    end
  end
end
