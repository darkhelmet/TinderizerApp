require 'json'
require 'rest-client'

module Loggly
  Root = JSON.parse(File.read('config/config.json'))['loggly']

  class << self
    def method_missing(sym, *args, &block)
      message = args.join('; ')
      timestamp = Time.now.utc.strftime("%Y-%m-%dT%l:%M:%S%z")
      RestClient.post(Root, "*** #{sym.to_s.upcase} *** - #{timestamp} - #{message}")
    end
  end
end
