module Fluent
  class MyAsyncOutput < Output
    config_param :try_flush_interval, :float, :default => 0.1
    config_param :shutdown_timeout, :integer, :default => 20

    def configure(conf)
      super
    end

    def start
      super

      @running =  true
      @mutex = Mutex.new
      @queue = []
      @thread = Thread.new(&method(:try_flush))
    end

    def shutdown
      @running = false
      # FIXME: I don't know, but thread is stuck unless @shutdown_timeout
      @thread.join(@shutdown_timeout) if @thread
      super
    end

    def try_flush
      while @running
        if @queue.size < 1
          sleep(@try_flush_interval)
          next
        end

        events = @mutex.synchronize {
          events, @queue = @queue, []
          events
        }
        write(events)
      end
    end

    def emit(tag, es, chain)
      events = []
      es.each {|time,record|
        events << [tag, time, record]
      }
      @mutex.synchronize {
        @queue += events
      }

      chain.next
    end

    # Override Me!
    def write(events)
      events.each {|tag, time, record| }
    end
  end
end
