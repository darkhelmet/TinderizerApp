$: << File.expand_path(File.join('.', 'lib'))
require 'setup'
require 'environment'

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
