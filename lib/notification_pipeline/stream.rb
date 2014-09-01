module NotificationPipeline
 class Notification < OpenStruct
  end


  # Stream is a list of notifications for a subscriber. This is a presentation object.
  # It provides the highest abstraction possible and should be the only notification component
  # used in your rendering/mark-read code.
  class Stream < Array
    def initialize(id, persisted, channels)
      @id = id # this could be the user id, as a stream is per subscriber.

      # this can be optimized!
      # transform new messages to notifications.
      channels.each do |name, messages|
        messages.each { |msg| self << persist!(msg.merge(read: false, stream_id: id)) } # Notification can be persistent. it is only created when stream is requested!
      end

      @read_count = 0
    end

    def unread_count
      count - @read_count
    end

    def read!(id)
      return false unless notification = find { |ntf| ntf.id == id }
      return false if notification.read

      @read_count += 1
      notification.read = true
    end

  private
    attr_reader :id

    def persist!(msg)
      # redis[stream][id] <<
      Notification.new(msg)
    end


    require 'redis'
    class Redis < self
      def self.build(store, id, broadcast)
         # "new-songs" => subject["new-songs", 0]
         persisted = store.lrange("stream:#{id}", 0, -1)
        new(store, id, persisted, [])
      end

      def initialize(store, *args)
        super(*args)
        @store = store
      end

      # def persist!(msg)
      #   Redis.new
      # end
    end
  end
end