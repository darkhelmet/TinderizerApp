configure do
  disable(:lock)
  # Always reload bookmarklet in development mode
  set({
    redis: Redis.new,
    async: Async.new,
    bookmarklet: -> { File.read('public/bookmarklet.js') }
  })
end

configure :production do
  use(HoptoadNotifier::Rack)
  # But in production, compress and cache it
  set({
    haml: { ugly: true },
    bookmarklet: YUICompressor.compress_js(settings.bookmarklet, munge: true)
  })
end
