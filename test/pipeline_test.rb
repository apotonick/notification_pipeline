require 'test_helper'

require 'ostruct'
module NotificationPipeline
  # This can actually be kept in-memory in a daemon process.
  class Broadcast
    def initialize
      @channels = {}
    end

    def [](name, i=0) # {new-songs: 1, new-albums: 3, pm-1: 0}
      channel(name)[i]
    end

    def []=(name, message)
      channel(name) << message
    end

  private
    def channel(name)
      @channels[name] ||= Channel.new
    end
  end

  # A Channel is a list of messages, usually "notifications" for a particular group, thread or object.
  # Each message represents an event subscribers want to know about, like "Garrett liked photo XyZ!".
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

    def persist!(hash)
      Notification.new(hash)
    end
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
    subject.send(:channel, "new-songs").extend(Now)


    subject["new-songs"]= hsh1 = {message: "Drones"}
    subject["new-songs"]= hsh2 = {message: "Them And Us"}

    subject["new-bands"]= hsh3 = {message: "Vention Dention"}

    # i = 0
    subject["new-songs", 0].must_equal [
      {message: "Drones",      created_at: Now::NOW, id: hsh1.object_id},
      {message: "Them And Us", created_at: Now::NOW, id: hsh2.object_id}] # next_i => 1

    # i > 0
    subject["new-songs", 1].must_equal [{message: "Them And Us", created_at: Now::NOW, id: hsh2.object_id}] # next_i => 1

    # Subscriber[1]{new-songs: 1, new-albums: 3, pm-1: 0}

    # Broadcast[new-songs: 1, new-albums: 3, pm-1: 0]


    # subscriber has to remember next index. or:
    #subject["new-songs", subscriber] # Broadcast remembers last i.

    # Notification#read!

    # Stream is "notifications" table or a Redis array per subscriber.
    stream = NotificationPipeline::Stream.new(1, [], "new-songs" => subject["new-songs", 0])

    # #count is unread notifications
    stream.count.must_equal 2
    stream.unread_count.must_equal 2

    stream.to_a.must_equal [
      notif1 = Notification.new({message: "Drones",      created_at: Now::NOW, id: hsh1.object_id, read: false, stream_id: 1}),
      notif2 = Notification.new({message: "Them And Us", created_at: Now::NOW, id: hsh2.object_id, read: false, stream_id: 1}),
    ]

    # #read! non-existent
    stream.read!(0).must_equal false

    # #read! exists
    stream.read!(notif1.id).must_equal true
    stream.count.must_equal 2
    stream.unread_count.must_equal 1

    # call it again, accidentially
    stream.read!(notif1.id).must_equal false
    stream.count.must_equal 2
    stream.unread_count.must_equal 1


    # Stream.from(User.notifications, Broadcast...)

    # Subscriber has a stream, channels: last_i
  end
end