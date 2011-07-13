module Blacklist
  class << self
    def blacklist!(redis, url)
      redis.setex(make_key(url), 24.hours, url)
    end

    def unless_blacklisted(redis, url)
      if redis.get(make_key(url))
        { message: "Sorry but this URL has proven to not work, and has been blacklisted." }.to_json
      else
        yield
      end
    end

  private

    def make_key(url)
      ['blacklist', Digest::SHA1.hexdigest(url)].join(':')
    end
  end
end