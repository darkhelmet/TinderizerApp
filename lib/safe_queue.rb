require 'girl_friday'
require 'hoptoad_notifier'
require 'user'

module SafeQueue
  class << self
    def build(queue, &block)
      GirlFriday::WorkQueue.new(queue) do |message|
        begin
          block.call(message)
        rescue Exception => boom
          User.notify(Redis.new, message[:key], "Unexpected error occurred. Developer notified.")
          HoptoadNotifier.notify_or_ignore(boom)
        end
      end
    end
  end
end
