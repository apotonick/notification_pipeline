require 'test_helper'

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
    it("redis") do
      broadcast.send(:channel, "new-songs").extend(Now)


      broadcast["new-songs"]= hsh1 = {message: "Drones"}
      broadcast["new-songs"]= hsh2 = {message: "Them And Us"} # eat this
      broadcast["new-bands"]= hsh3 = {message: "Vention Dention"} # eat this


      snapshot = {"new-songs" => 1, "new-bands" => 0} # from Subscriber.
      stream, new_snapshot = NotificationPipeline::Stream::Redis.build(store, 1, broadcast, snapshot)
      stream.size.must_equal 2

      new_snapshot.must_equal("new-songs" => 2, "new-bands" => 1) # this is for the next lookup.
      store.llen("stream:1").must_equal 2 # since we retrieved 2 items, they get persisted.
      # store.lrange("stream:1", 0, -1).collect { |ser| Marshal.load(ser) }.must_equal ""

      # refresh stream without any new messages.
      puts "next build"
      stream, new_snapshot = NotificationPipeline::Stream::Redis.build(store, 1, broadcast, new_snapshot)
      new_snapshot.must_equal("new-songs" => 2, "new-bands" => 1)
      store.llen("stream:1").must_equal 2
      stream.size.must_equal 2


      # one more message.
      broadcast["new-bands"]= hsh3 = {message: "Yngwie Malmsteen"} # eat this

      stream, new_snapshot = NotificationPipeline::Stream::Redis.build(store, 1, broadcast, new_snapshot)
      new_snapshot.must_equal("new-songs" => 2, "new-bands" => 2)
      store.llen("stream:1").must_equal 3
      stream.size.must_equal 3

      # stream API returns hash.
      # #[]
      stream[0][:message].must_equal "Them And Us"
      stream[1][:message].must_equal "Vention Dention"
      stream[2][:message].must_equal "Yngwie Malmsteen"

      # #each
      stream.each.to_a.map{ |el| el[:message] }.must_equal ["Them And Us", "Vention Dention", "Yngwie Malmsteen"]
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
      notif1 = {message: "Drones",      created_at: Now::NOW, id: hsh1.object_id, read: false, stream_id: 1},
      notif2 = {message: "Them And Us", created_at: Now::NOW, id: hsh2.object_id, read: false, stream_id: 1},
    ]

    # #read! non-existent
    stream.read!(0).must_equal false

    # #read! exists
    stream.read!(notif1[:id]).must_equal true
    stream.count.must_equal 2
    stream.unread_count.must_equal 1

    # call it again, accidentially
    stream.read!(notif1[:id]).must_equal false
    stream.count.must_equal 2
    stream.unread_count.must_equal 1


    # Stream.from(User.notifications, Broadcast...)

    # Subscriber has a stream, channels: last_i
  end
end