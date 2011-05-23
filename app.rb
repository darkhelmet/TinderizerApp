$: << File.expand_path(File.join('.', 'lib'))

require 'bundler/setup'
require 'sinatra'
require 'newrelic_rpm'
require 'json'
require 'active_support'
ActiveSupport::JSON.backend = :JSONGem
require 'hoptoad_notifier'

HoptoadNotifier.configure do |config|
  config.api_key = JSON.parse(File.read('config/config.json'))['hoptoad']
end

require 'haml'
require 'yuicompressor'
require 'redis'
require 'digest/sha1'
require 'lib/sinatra/render'
require 'async'
require 'rate_limit'

# jruby fails me: http://jira.codehaus.org/browse/JRUBY-5529
require 'net/http' # Just to ensure that's loaded
Net::BufferedIO.class_eval do
  BUFSIZE = 1024 * 16

  def rbuf_fill
    timeout(@read_timeout) { @rbuf << @io.sysread(BUFSIZE) }
  end
end

configure do
  disable(:lock)
  set(:redis, Redis.new)
  set(:async, Async.new)
  # Always reload bookmarklet in development mode
  set(:bookmarklet, -> { File.read('public/bookmarklet.js') })
end

configure :production do
  use(HoptoadNotifier::Rack)
  set(:haml, ugly: true)
  # But in production, compress and cache it
  bookmarklet = YUICompressor.compress_js(settings.bookmarklet, :munge => true)
  set(:bookmarklet, bookmarklet)
end

before do
  headers 'Access-Control-Allow-Origin' => '*'
end

get '/ajax/submit.json' do
  redis = settings.redis
  email, url = params.values_at(:email, :url)
  limit_key = Digest::SHA1.hexdigest(email)
  RateLimit.limit(redis, limit_key, 60) do
    key = Digest::SHA1.hexdigest([email, url, Time.now.to_s].join(':'))
    message = { :email => params[:email], :url => params[:url], :key => key }
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
