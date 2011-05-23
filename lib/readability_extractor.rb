require 'java'

java_import com.darkhax.Readability

class ReadabilityExtractor
  def initialize(url, destination)
    @url = url
    @dir = destination
  end

  def extract!
    readability = Readability.new(@url)
    tuple = readability.summary
    element, title, image_map = tuple._1, tuple._2, tuple._3
    File.open(outfile, 'w') { |f| f.write(element.to_s) }
    [outfile, title, image_map]
  end

private

  def outfile
    File.join(@dir, 'out.html')
  end
end