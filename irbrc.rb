require 'java'
Dir['lib/*.jar'].each { |jar| require jar }
$CLASSPATH << 'classes'
$CLASSPATH << 'vendor/goose/target/classes'
