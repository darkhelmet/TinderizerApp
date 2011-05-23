require 'java'
Dir['lib/*.jar'].each do |jar|
  require jar
end
$CLASSPATH << 'classes'
$CLASSPATH << 'vendor/goose/target/classes'
