#!/usr/bin/env ruby
Dir.glob("test/**/test_*.rb") do |test_rb|
  require File.expand_path(test_rb)
end
