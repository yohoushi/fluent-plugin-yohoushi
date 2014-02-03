module Fluent
  module Test
    class MyAsyncOutputTestDriver < InputTestDriver
      def initialize(klass, tag='test', &block)
        super(klass, &block)
        @entries = []
        @tag = tag
      end

      attr_accessor :tag

      def emit(record, time=Time.now)
        @entries << [time.to_i, record]
        self
      end

      def run(&block)
        result = nil
        super {
          es = ArrayEventStream.new(@entries)

          events = []
          es.each {|time,record|
            events << [@tag, time, record]
          }

          block.call if block

          result = @instance.write(events)
        }
        result
      end
    end
  end
end
