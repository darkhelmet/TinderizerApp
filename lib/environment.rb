configure do
  disable(:lock)
  # Always reload bookmarklet in development mode
  set({
    redis: Redis.new,
    async: Async.new,
    limit: 2,
    bookmarklet: -> { File.read('public/bookmarklet.js') }
  })
end

configure :production do
  use(HoptoadNotifier::Rack)
  set({
    haml: { ugly: true },
    limit: 10,
    bookmarklet: File.read('public/bookmarklet.min.js')
  })
end
