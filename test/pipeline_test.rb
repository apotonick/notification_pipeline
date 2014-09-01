require 'test_helper'

require 'ostruct'
module NotificationPipeline

end

class PipelineTest < MiniTest::Spec
  Notification = NotificationPipeline::Notification

  module Now
    NOW = Time.now

    def timestamp
      NOW
    end
  end

  let(:broadcast) { NotificationPipeline::Broadcast.new }



  # non-existent channel.
  it { broadcast["non-existent" => 0].must_equal [] }


  describe "Redis" do
    let (:store) { Redis.new }
    before { store.del("stream:1") }

    # redis
    it do
      broadcast.send(:channel, "new-songs").extend(Now)


      broadcast["new-songs"]= hsh1 = {message: "Drones"}
      broadcast["new-songs"]= hsh2 = {message: "Them And Us"}
      broadcast["new-bands"]= hsh3 = {message: "Vention Dention"}


      snapshot = {"new-songs" => 1, "new-bands" => 0} # from Subscriber.
      stream = NotificationPipeline::Stream::Redis.build(store, 1, broadcast, snapshot)

      store.llen("stream:1").must_equal 2
      store.lrange("stream:1", 0, -1).must_equal ""
    end
  end




  # push and read.
  it do
    broadcast.send(:channel, "new-songs").extend(Now)


    broadcast["new-songs"]= hsh1 = {message: "Drones"}
    broadcast["new-songs"]= hsh2 = {message: "Them And Us"}

    broadcast["new-bands"]= hsh3 = {message: "Vention Dention"}

    # Subscriber.to_hash #=> {"new-songs"=> 0, "new-bands" => 1}
    # broadcast[{"new-songs"=> 0}].to_hash

    # i = 0
    broadcast["new-songs" => 0].must_be_kind_of NotificationPipeline::Broadcast::Messages
    broadcast["new-songs" => 0].must_equal [
      {message: "Drones",      created_at: Now::NOW, id: hsh1.object_id},
      {message: "Them And Us", created_at: Now::NOW, id: hsh2.object_id}] # next_i => 1
    # #to_hash
    broadcast["new-songs" => 0].to_hash.must_equal({"new-songs" => 2})

    # i > 0
    broadcast["new-songs" => 1].must_equal [{message: "Them And Us", created_at: Now::NOW, id: hsh2.object_id}] # next_i => 1
    broadcast["new-songs" => 1].to_hash.must_equal({"new-songs" => 2})

    # Subscriber[1]{new-songs: 1, new-albums: 3, pm-1: 0}

    # Stream is a virtual, non-persistent model.
    # Broadcast[new-songs: 1, new-albums: 3, pm-1: 0]
    # NotificationPipeline::Stream.new(1, [], "new-songs" => broadcast["new-songs", 0]) # id, persisted notification (in stream), new messages


    # subscriber has to remember next index. or:
    #subject["new-songs", subscriber] # Broadcast remembers last i.

    # Notification#read!

    # Stream is "notifications" table or a Redis array per subscriber.
    # Stream::Redis.build(store, 1, broadcast)
    stream = NotificationPipeline::Stream.new(1, [], broadcast["new-songs" => 0])

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