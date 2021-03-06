module NotificationPipeline
  require 'ostruct'
  class Notification < OpenStruct
  end


  # Stream is a list of notifications for a subscriber. This is a presentation object.
  # It provides the highest abstraction possible and should be the only notification component
  # used in your rendering/mark-read code.
  class Stream < Array
    def initialize(id, persisted, new_messages)
      @id = id # this could be the user id, as a stream is per subscriber.

      # this can be optimized!
      # transform new messages to notifications.
      push(*persisted)

      new_messages.each do |msg|
        self << persist!(msg.merge("read" => false, "stream_id" => id)) # Notification can be persistent. it is only created when stream is requested!
      end

      @read_count = 0
    end

    def unread_count
      count - @read_count
    end

    def read!(id)
      return false unless notification = find { |ntf| ntf[:id] == id }
      return false if notification[:read]

      @read_count += 1
      notification[:read] = true
    end

  private
    attr_reader :id

    def persist!(msg)
      # redis[stream][id] <<
      # Notification.new(msg)
      msg
    end


    require 'redis'
    class Redis < self
      def self.build(store, broadcast, subscriber)
        # "new-songs" => subject["new-songs", 0]
        persisted = retrieve!(store, subscriber.id) # serialised, persisted Notifications. from Redis.

        # here, we can check if any channel has changed and decide whether this stream needs to get updated or not.
         # puts "`````````````````````````````````` snapshot: #{subscriber.snapshot.inspect}"
        news      = broadcast[subscriber.snapshot] # generic.
         # puts "`````````````````````````````````` news:     #{news.inspect}"
        subscriber.snapshot = news.to_hash # DISCUSS: should that happen in Broadcast?


        # TODO: make broadcast[..] return [[Notification, Notification], snapshot]

        new(store, subscriber.id, persisted, news)
      end

      def initialize(store, *args)
        @store = store

        super(*args)
      end

    private
      def self.retrieve!(store, id)
        persisted = store.lrange("stream:#{id}", 0, -1)
        persisted.collect { |ser| Marshal.load(ser) } # FIXME: incredible slow.
      end

      # called from #initialize
      def persist!(msg) # TODO: they are no Notifications !
        @store.rpush("stream:#{id}", Marshal.dump(msg))
        msg
      end


      module Flush
        def flush! # DISCUSS: do we need this?
          @store.del("stream:#{id}")
        end
      end
    end
  end
end