# jruby fails me: http://jira.codehaus.org/browse/JRUBY-5529
require 'net/http' # Just to ensure that's loaded
Net::BufferedIO.class_eval do
  BUFSIZE = 1024 * 16

  def rbuf_fill
    timeout(@read_timeout) { @rbuf << @io.sysread(BUFSIZE) }
  end
end
