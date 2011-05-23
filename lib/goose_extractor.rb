require 'java'
$CLASSPATH << File.expand_path(File.join(File.dirname(__FILE__), '..', 'vendor', 'goose', 'target', 'classes'))

java_import com.jimplush.goose.ContentExtractor
java_import com.jimplush.goose.Configuration

class GooseExtractor
  def initialize(url, destination)
    @url = url
    @dir = destination
  end

  def extract!
    article = extractor.extract_content(@url)
    File.open(outfile, 'w') do |f|
      f.write(article.get_top_node.to_string)
    end
    [outfile, article.get_title, get_image_map(article.get_top_node)]
  end

private

  def outfile
    File.join(@dir, 'out.html')
  end

  def get_image_map(elem)
    {}
  end

  def extractor
    @extractor ||= begin
      ex = ContentExtractor.new(config)
    end
  end

  def config
    @config ||= begin
      c = Configuration.new
      c.set_enable_image_fetching(false)
      c
    end
  end
end