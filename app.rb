$: << File.expand_path(File.join('.', 'lib'))

%w(bundler/setup sinatra newrelic_rpm json active_support).each { |lib| require lib }
ActiveSupport::JSON.backend = :JSONGem
require 'hoptoad_notifier'

HoptoadNotifier.configure do |config|
  config.api_key = JSON.parse(File.read('config/config.json'))['hoptoad']
end

%w(haml yuicompressor redis digest/sha1 lib/sinatra/render async user jruby_ssl_fix).each { |lib| require lib }

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

before do
  # This needs to be set to allow the JSON to be had over XMLHttpRequest
  headers 'Access-Control-Allow-Origin' => '*'
end

get '/ajax/submit.json' do
  redis = settings.redis
  email, url = params.values_at(:email, :url)
  User.limit(redis, email, 60) do
    key = Digest::SHA1.hexdigest([email, url, Time.now.to_s].join(':'))
    message = { email: email, url: url, key: key }
    redis.set(key, 'Working...')
    settings.async.extractor << message
    { :message => 'Submitted! Hang tight...', :id => key }.to_json
  end
end

get '/ajax/status/:id.json' do |id|
  status = settings.redis.get(id)
  done = !status.match(/done|failed|limited/i).nil?
  { message: status, done: done }.to_json
end

get '/static/bookmarklet.js' do
  content_type(:js)
  settings.bookmarklet
end

get '/?' do
  haml(:index)
end

get %r{/(faq|firefox|safari|chrome|ie|bugs)} do |page|
  haml(page.to_sym)
end
