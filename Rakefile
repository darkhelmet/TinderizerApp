readability = File.join(File.dirname(__FILE__), 'lib/scala/Readability.scala')

task :build do
  system('scalac', '-deprecation', '-cp', 'lib/java/jsoup-1.5.2.jar', '-d', 'lib/java/', readability)
end

task :jars do
  `curl -L https://github.com/downloads/darkhelmet/kindlebility3/scala-library.jar -o lib/java/scala-library.jar`
  `curl -L https://github.com/downloads/darkhelmet/kindlebility3/jsoup-1.5.2.jar -o lib/java/jsoup-1.5.2.jar`
end