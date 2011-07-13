%w(newrelic_rpm json active_support active_support/core_ext).each { |lib| require lib }
ActiveSupport::JSON.backend = :JSONGem
require 'hoptoad_notifier'

HoptoadNotifier.configure do |config|
  config.api_key = JSON.parse(File.read('config/config.json'))['hoptoad']
end

%w(haml redis digest/sha1 lib/sinatra/render async user jruby_ssl_fix blacklist).each { |lib| require lib }
