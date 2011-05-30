module Extractor
  class Base
    attr_reader :url, :destination

    def initialize(url, destination)
      @url = url
      @destination = destination
      Dir.mkdir(destination)
    end

    def extract!
      raise 'You need to override this!'
    end

  protected

    def outfile
      File.join(destination, 'out.html')
    end
  end
end
