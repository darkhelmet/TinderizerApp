%w(newrelic_rpm json active_support).each { |lib| require lib }
ActiveSupport::JSON.backend = :JSONGem
require 'hoptoad_notifier'

HoptoadNotifier.configure do |config|
  config.api_key = JSON.parse(File.read('config/config.json'))['hoptoad']
end

%w(haml yuicompressor redis digest/sha1 lib/sinatra/render async user jruby_ssl_fix).each { |lib| require lib }
