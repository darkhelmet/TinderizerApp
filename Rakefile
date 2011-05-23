task :goose do
  Dir.chdir('vendor/goose') do
    system('mvn compile')
  end
end

task :jars do
  Dir.chdir('lib') do
    %w(
      https://github.com/downloads/darkhelmet/kindlebility3/scala-library.jar
      https://github.com/downloads/darkhelmet/kindlebility3/jsoup-1.5.2.jar
      https://github.com/downloads/darkhelmet/kindlebility3/slf4j-simple-1.6.1.jar
      https://github.com/downloads/darkhelmet/kindlebility3/slf4j-api-1.6.1.jar
      https://github.com/downloads/darkhelmet/kindlebility3/commons-io-1.3.2.jar
      https://github.com/downloads/darkhelmet/kindlebility3/apache-mime4j-0.6.jar
      https://github.com/downloads/darkhelmet/kindlebility3/commons-codec-1.3.jar
      https://github.com/downloads/darkhelmet/kindlebility3/commons-logging-1.1.1.jar
      https://github.com/downloads/darkhelmet/kindlebility3/httpclient-4.0.3.jar
      https://github.com/downloads/darkhelmet/kindlebility3/httpcore-4.0.1.jar
      https://github.com/downloads/darkhelmet/kindlebility3/httpmime-4.0.3.jar
      https://github.com/downloads/darkhelmet/kindlebility3/commons-lang-2.6.jar
      https://github.com/downloads/darkhelmet/kindlebility3/log4j-over-slf4j-1.6.1.jar
    ).each do |url|
      file = url.split('/').last
      system('curl', '-L', url, '-o', file)
    end
  end
end
