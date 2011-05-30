%w(redis girl_friday user loggly hoptoad_notifier).each { |lib| require lib }

module SafeQueue
  RedisClient = Redis.new

  class << self
    def build(queue, &block)
      GirlFriday::WorkQueue.new(queue) do |message|
        begin
          block.call(message)
        rescue Exception => boom
          HoptoadNotifier.notify_or_ignore(boom)
          User.notify(RedisClient, message[:key], "Unexpected error occurred; processing failed. Developer notified.")
          Loggly.error("Caught error in queue #{queue}: #{boom.message}")
        end
      end
    end
  end
end
