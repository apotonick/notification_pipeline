module NotificationPipeline
  # This can actually be kept in-memory in a daemon process.
  # Channel class per channel to make it possible to have different backends for different channels.
  class Broadcast
    def initialize
      @channels = {}
    end

    # Broadcast::[] is the only public reader for messages in a set of channels.
    # Returns Messages. API: Messages#each, Messages#to_hash, which returns the snapshot.
    # TODO: make broadcast[..] return [[Notification, Notification], snapshot]
    def [](hash) # {new-songs: 1, new-albums: 3, pm-1: 0}
      # here, we could keep last_i for every channel so we don't need to do channel[i], which is costly.
      snapshot = {}

      Messages.new hash.collect { |name, i|
        res = channel(name)[i] # [[..], 2] # here, we could only open channels that have changed.
        snapshot[name] = res.last
        res.first
      }.flatten, snapshot # TODO: optimise as this is the bottleneck.
    end

    def []=(name, message)
      # this should be something like channel_push(name, message) where we can decide whether to do channel(name).messages << (AR) or just hardcore-push to channel[name]<< (Redis).
      channel(name) << message
    end

  private
    def channel(name)
      @channels[name] ||= build_channel(name)
    end

    def build_channel(name)
      # this is where we can find/create channel?
      # to add, we don't need to find the channel, though.
      Channel.new
    end

    # Not sure yet if we need that.
    class Messages < Array
      def initialize(msgs, snapshot={})
        # we could do BC#[] here?
        super(msgs)
        @snapshot = snapshot
      end

      def to_hash
        @snapshot
      end
    end
  end

  # A Channel is a list of messages, usually "notifications" for a particular group, thread or object.
  # Each message represents what an event subscribers want to know about, like "Garrett liked photo XyZ!".
  class Channel < Array
    def <<(hash)
      persist(hash)
    end

    def [](i)
      [read(i), last_index]
    end

  private
    def last_index
      size
    end

    def persist(hash)
      # persist Notification, e.g. into Redis or AR. Or array.

      # this must be implemented by bg engine.
      hash = hash.merge(created_at: timestamp, id: hash.object_id)
      push(hash)
    end

    # this is where we could also read from DB or Redis.
    def read(i)
      slice(i..-1)
      # Redis slice
      # where channel_id=1 and index>=2
    end

    def timestamp
      Time.now
    end
  end
end