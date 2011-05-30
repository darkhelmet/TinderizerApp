require 'java'

java_import com.darkhax.Readability

module Extractor
  class ScalaReadability
    def extract!
      tuple = Readability.apply(@url)
      element, title, image_map = tuple._1, tuple._2, tuple._3
      File.open(outfile, 'w') { |f| f.write(element.to_s) }
      [outfile, title, image_map]
    end
  end
end
