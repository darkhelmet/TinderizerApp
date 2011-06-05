require 'extractor/base'
require 'rest-client'
require 'cgi'
require 'json'
require 'maybe_monad'
require 'java'
require 'digest/sha1'
require 'uri'
require 'image_monster'

java_import org.jsoup.Jsoup

module Extractor
  class ReadabilityApi < Base
    Token = JSON.parse(File.read('config/config.json'))['readability']
    Root = 'https://readability.com/api/content/v1/parser'

    def extract!
      response = JSON.parse(RestClient.get(build_url(url)))
      title, domain, author, html = response.values_at(*%w(title domain author content))
      write_html(rewrite_and_download_images(html), title)
      author = Maybe(author).or_else('Kindlebility') + " (#{domain})"
      [outfile, title, author]
    end

  private

    def write_html(html, title)
      File.open(outfile, 'w') do |f|
        f.write("<h1>#{title}</h1>\n")
        f.write(html)
      end
    end

    def build_url(url)
      Root + "?url=" + CGI.escape(url) + "&token=" + CGI.escape(Token)
    end

    def rewrite_and_download_images(html)
      doc = Jsoup.parse(html)
      image_map = doc.get_elements_by_tag('img').inject({}) do |map, img|
        url = img.attr('src')
        rewritten = Digest::SHA1.hexdigest(url)
        img.attr('src', rewritten)
        map.merge(url => rewritten)
      end
      ImageMonster.eat(image_map, destination)
      doc.get_elements_by_tag('body').first.html
    end
  end
end
