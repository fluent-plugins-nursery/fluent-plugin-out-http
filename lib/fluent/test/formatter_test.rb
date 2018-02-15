require 'fluent/formatter'

module Fluent
  module TextFormatter
    class TestFormatter < Formatter
      Plugin.register_formatter('test_formatter', self)

      def configure(conf)
        super
      end

      def format(tag, time, record)
        output = {
          "wrapped" => true,
          "record" => record
        }
        output
      end
    end
  end
end
