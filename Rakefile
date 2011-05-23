task :build do
  readability = File.join(File.dirname(__FILE__), 'lib/scala/Readability.scala')
  system('scalac', '-deprecation', '-cp', 'lib/jsoup-1.5.2.jar', '-d', 'classes', readability)
end

task :jars do
  `curl -L https://github.com/downloads/darkhelmet/kindlebility3/scala-library.jar -o lib/scala-library.jar`
  `curl -L https://github.com/downloads/darkhelmet/kindlebility3/jsoup-1.5.2.jar -o lib/jsoup-1.5.2.jar`
end
