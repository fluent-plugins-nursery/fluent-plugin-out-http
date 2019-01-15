require 'fluent/plugin/formatter'

module Fluent
  module Plugin
    class TestFormatter < Formatter
      Fluent::Plugin.register_formatter('test', self)

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
