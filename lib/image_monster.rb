require 'thread_storm'
require 'rest-client'

module ImageMonster
  class << self
    def eat(map, directory)
      pool = ThreadStorm.new(size: 5)
      map.each do |original, file|
        output = File.join(directory, file)
        pool.execute do
          image = RestClient.get(original) rescue ''
          File.open(output, 'w') { |f| f.write(image) }
        end
      end
      pool.join
    end
  end
end