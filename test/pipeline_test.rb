require 'test_helper'

require 'ostruct'
module NotificationPipeline
  # This can actually be kept in-memory in a daemon process.
  class Broadcast
    def initialize
      @channels = {}
    end

    def [](name, i=nil)
      return channel(name) unless i
      channel(name)[i]
    end

    def channel(name)
      @channels[name] ||= Channel.new
    end
  end

  # A Channel is a list of messages, usually "notifications" for a particular group, thread or object.
  # Each message represents an event subscribers want to know about, like "Garrett liked photo XyZ!".
  class Channel < Array
    def <<(hash)
      hash = hash.merge(created_at: timestamp)

      persist!(hash)
    end

    def [](i)
      read(i)
    end

  private
    def persist!(hash)
      # persist Notification, e.g. into Redis or AR. Or array.
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

  class Notification < OpenStruct

  end
end

class PipelineTest < MiniTest::Spec
  Notification = NotificationPipeline::Notification

  module Now
    NOW = Time.now

    def timestamp
      NOW
    end
  end

  subject { NotificationPipeline::Broadcast.new }

  # non-existent channel.
  it { subject["non-existent", 0].must_equal [] }

  # push and read.
  it do
    subject["new-songs"].extend(Now)

    subject["new-songs"] << {message: "Drones"}
    subject["new-songs"] << {message: "Them And Us"}

    subject["new-songs", 0].must_equal [{message: "Drones", created_at: Now::NOW}, {message: "Them And Us", created_at: Now::NOW}] # next_i => 1
    subject["new-songs", 1].must_equal [{message: "Them And Us", created_at: Now::NOW}] # next_i => 1

    # subscriber has to remember next index. or:
    #subject["new-songs", subscriber] # Broadcast remembers last i.

    # Stream[Notification{stream}, Notification{stream}] => to be displayed
    # Stream#count
    # Notification#read!

    # Stream is "notifications" table or a Redis array per subscriber.
    NotificationPipeline::Stream.new("new-songs" => subject["new-songs", 0])
  end
end