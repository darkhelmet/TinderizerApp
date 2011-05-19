$: << File.expand_path(File.join('.', 'lib'))

require 'bundler/setup'
require 'sinatra'
require 'haml'
require 'yuicompressor'
require 'json'
require 'redis'
require 'digest/sha1'
require 'rack/deflater'
require 'lib/sinatra/render'
require 'async'

configure do
  disable(:lock)
  set(:async, Async.new)
  set(:bookmarklet, -> { File.read('public/bookmarklet.js') })
end

configure :production do
  set(:haml, ugly: true)
  bookmarklet = YUICompressor.compress_js(settings.bookmarklet, :munge => true)
  set(:bookmarklet, bookmarklet)
  use Rack::Deflater
end

before do
  headers 'Access-Control-Allow-Origin' => '*'
end

get '/ajax/submit.json' do
  redis = Redis.new
  # TODO: Rate limiting
  email, url = params.values_at(:email, :url)
  key = Digest::SHA1.hexdigest([email, url, Time.now.to_s].join(':'))
  message = { :email => params[:email], :url => params[:url], :key => key }
  settings.async.extractor << message
  redis.set(key, 'Working...')
  { :message => 'Submitted! Hang tight...', :id => key }.to_json
end

get '/ajax/status/:id.json' do |id|
  redis = Redis.new
  status = redis.get(id)
  done = !status.match(/done|failed/i).nil?
  { message: status, done: done }.to_json
end

get '/static/bookmarklet.js' do
  content_type(:js)
  settings.bookmarklet
end

get '/?' do
  haml(:index)
end

get '/faq' do
  'TODO'
end

get '/firefox' do
  'TODO'
end

get '/safari' do
  'TODO'
end

get '/chrome' do
  'TODO'
end

get '/ie' do
  'TODO'
end