require 'redis'

module User
  class << self
    def notify(redis, key, message)
      redis.multi do
        redis.set(key, message)
        redis.expire(key, 30)
      end
    end
  end
end
