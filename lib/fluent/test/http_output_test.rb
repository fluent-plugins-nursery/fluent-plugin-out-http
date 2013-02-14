require 'rubygems'
require 'bundler'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

require 'test/unit'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'fluent/test'

unless ENV.has_key?('VERBOSE')
  nulllogger = Object.new
  nulllogger.instance_eval {|obj|
    def method_missing(method, *args)
      # pass
    end
  }
  $log = nulllogger
end

class Test::Unit::TestCase
end

require 'webrick'

# to handle POST/PUT/DELETE ...
module WEBrick::HTTPServlet
  class ProcHandler < AbstractServlet
    alias do_POST   do_GET
    alias do_PUT    do_GET
    alias do_DELETE do_GET
  end
end

def get_code(server, port, path, headers={})
  require 'net/http' 
  Net::HTTP.start(server, port){|http|
    http.get(path, headers).code
  } 
end 
def get_content(server, port, path, headers={})
  require 'net/http'
  Net::HTTP.start(server, port){|http|
    http.get(path, headers).body
  } 
end
