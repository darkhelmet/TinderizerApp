require 'extractor/base'
require 'active_support'
require 'rest-client'
require 'json'
require 'maybe_monad'
require 'java'
require 'digest/sha1'
require 'uri'
require 'thread_storm'
require 'nokogiri'
require 'rack'

module Extractor
  class ReadabilityApi < Base
    Token = JSON.parse(File.read('config/config.json'))['readability']
    Root = 'https://readability.com/api/content/v1/parser'

    def extract!
      response = JSON.parse(RestClient.get(build_url(url)))
      raise BlacklistError if response['title'] =~ /Article Could not be Parsed/i
      title, domain, author, html = response.values_at(*%w(title domain author content))
      @outfile = File.join(destination, "#{title.parameterize.to_s}.html")
      author = Maybe(author).or_else('Tinderizer') + " (#{domain})"
      write_html(rewrite_and_download_images(html), author, title)
      [outfile, title, author]
    end

  protected

    def outfile
      @outfile
    end

  private

    def write_html(html, author, title)
      File.open(outfile, 'w') do |f|
        f.write('<html>')
        f.write(%Q{<meta content="text/html, charset=utf-8" http-equiv="Content-Type" />})
        f.write(%Q{<meta content="#{author}" name="author" />})
        f.write(%Q{<title>#{title}</title>})
        f.write(html.sub('<body>', "<body>\n<h1>#{title}</h1>\n"))
        f.write('<html/>')
      end
    end

    def build_url(url)
      Root + "?url=" + Rack::Utils.escape(url) + "&token=" + Rack::Utils.escape(Token)
    end

    def rewrite_and_download_images(html)
      doc = Nokogiri::HTML(html)
      ThreadStorm.new(size: 5) do |pool|
        doc.search('img').each do |img|
          url = img['src']
          pool.execute do
            data, filename = download_image_or_default(url)
            File.open(File.join(destination, filename), 'w') { |f| f.write(data) }
            img['src'] = filename
          end
        end
      end
      doc.search('body').first.to_html
    end

    def download_image_or_default(url)
      hash = Digest::SHA1.hexdigest(url)
      resp = RestClient.get(url)
      ext = resp.headers[:content_type].split('/').last
      [resp, [hash, ext].join('.')]
    rescue => boom
      p boom.message
      ['', hash]
    end
  end
end
