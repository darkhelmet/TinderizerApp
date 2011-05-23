module RateLimit
  Lua = <<-LUA
    local value = redis('get', KEYS[1])
    if value ~= nil then return {err='limited'} end
    redis('set', KEYS[1], 'locked')
    redis('expire', KEYS[1], tonumber(ARGV[1]))
    return {ok='locked'}
  LUA

  class << self
    def limit(redis, key, time)
      redis.eval(Lua, 1, key, time)
      yield
    rescue RuntimeError => limited
      { :message => "Sorry, but there's a rate-limit, and you've hit it! Try again in a minute.", :limited => true }.to_json
    end
  end
end
