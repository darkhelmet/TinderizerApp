configure do
  disable(:lock)
  # Always reload bookmarklet in development mode
  set({
    redis: Redis.new,
    async: Async.new,
    limit: 5,
    bookmarklet: -> { File.read('public/bookmarklet.js') }
  })
end

configure :production do
  use(HoptoadNotifier::Rack)
  # But in production, compress and cache it
  set({
    haml: { ugly: true },
    limit: 60,
    bookmarklet: YUICompressor.compress_js(settings.bookmarklet, munge: true)
  })
end
