require 'test_helper'

require 'ostruct'
module NotificationPipeline
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

  class Channel < Array
    def <<(hash)
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
  end

  class Notification < OpenStruct

  end
end

class PipelineTest < MiniTest::Spec
  Notification = NotificationPipeline::Notification

  subject { NotificationPipeline::Broadcast.new }

  # non-existent channel.
  it { subject["non-existent", 0].must_equal [] }

  # push and read.
  it do
    subject["new-songs"] << {message: "Drones"}
    subject["new-songs"] << {message: "Them And Us"}

    subject["new-songs", 0].must_equal [{message: "Drones"}, {message: "Them And Us"}] # next_i => 1
    subject["new-songs", 1].must_equal [{message: "Them And Us"}] # next_i => 1

    # subscriber has to remember next index. or:
    #subject["new-songs", subscriber] # Broadcast remembers last i.

    # Stream[Notification{stream}, Notification{stream}] => to be displayed
    # Stream#count
    # Notification#read!

    # Stream is "notifications" table or a Redis array per subscriber.

  end
end