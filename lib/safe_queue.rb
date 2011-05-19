require 'girl_friday'
require 'user'
require 'loggly'

module SafeQueue
  class << self
    def build(queue, &block)
      GirlFriday::WorkQueue.new(queue) do |message|
        begin
          block.call(message)
        rescue Exception => boom
          User.notify(Redis.new, message[:key], "Unexpected error occurred; processing failed. Developer notified.")
          Loggly.error("Caught error in queue #{queue}: #{boom.message}")
          HoptoadNotifier.notify_or_ignore(boom)
        end
      end
    end
  end
end
