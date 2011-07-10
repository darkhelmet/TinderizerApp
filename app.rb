$: << File.expand_path(File.join('.', 'lib'))
require 'bundler/setup'
require 'sinatra'
require 'setup'
require 'environment'
require 'uri'
require 'cgi'

Host = 'kindlebility.com'

before do
  # This needs to be set to allow the JSON to be had over XMLHttpRequest
  headers 'Access-Control-Allow-Origin' => '*'
  if production?
    uri = URI(request.url)
    unless uri.host == Host
      unless uri.path.start_with?('/ajax')
        uri.port = 80
        uri.host = Host
        halt(301, { 'Location' => uri.to_s }, 'Redirecting')
      end
    end
  end
end

get '/ajax/submit.json' do
  content_type(:json)
  redis = settings.redis
  email, url = params.values_at(:email, :url)
  email = CGI.unescape(email).strip # Just in case...
  User.limit(redis, email, settings.limit) do
    key = Digest::SHA1.hexdigest([email, url, Time.now.to_s].join(':'))
    message = { email: email, url: url, key: key }
    redis.set(key, 'Working...')
    settings.async.extractor << message
    { :message => 'Submitted! Hang tight...', :id => key }.to_json
  end
end

get '/ajax/status/:id.json' do |id|
  content_type(:json)
  status = settings.redis.get(id)
  done = !status.match(/done|failed|limited|invalid/i).nil?
  { message: status, done: done }.to_json
end

get '/static/bookmarklet.js' do
  content_type(:js)
  settings.bookmarklet
end

get '/?' do
  haml(:index)
end

get '/kindle-email' do
  haml(:kindle_email, :layout => false)
end

get %r{/(firefox|safari|chrome|ie|ios)} do |page|
  haml(page.to_sym, :layout => false)
end

get %r{/(faq|bugs)} do |page|
  haml(page.to_sym)
end
