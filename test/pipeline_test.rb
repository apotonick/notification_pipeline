require 'test_helper'

class PipelineTest < MiniTest::Spec
  Notification = NotificationPipeline::Notification
  Subscriber = NotificationPipeline::Subscriber

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
    before {
      store.del("stream:1")
      store.del("stream:2")
    }

    let (:subscriber) { Subscriber.new(1, {"new-songs" => 1, "new-bands" => 0}) }


    # Broadcast#[]
    it"xxxx" do
      broadcast["new-bands"]= {message: "Helloween"}
      broadcast["new-songs"]= {message: "Drones"}

      # empty snapshot means there shouldn't be any messages.
      stream = NotificationPipeline::Stream::Redis.build(store, broadcast, Subscriber.new(2, {}))
      stream.size.must_equal 0

      # first, sucessfully retrieve.
      stream = NotificationPipeline::Stream::Redis.build(store, broadcast, Subscriber.new(2, {"new-songs" => 0}))
      stream.size.must_equal 1

      # even if snapshot is empty now, we still retrieve the previously persisted message
      stream = NotificationPipeline::Stream::Redis.build(store, broadcast, Subscriber.new(2, {}))
      stream.size.must_equal 1
    end

    # redis
    it("redis") do
      broadcast.send(:channel, "new-songs").extend(Now)


      broadcast["new-songs"]= hsh1 = {message: "Drones"}
      broadcast["new-songs"]= hsh2 = {message: "Them And Us"} # eat this
      broadcast["new-bands"]= hsh3 = {message: "Vention Dention"} # eat this

      # user, no channels
      stream = NotificationPipeline::Stream::Redis.build(store, broadcast, Subscriber.new(2, {}))
      stream.size.must_equal 0


      # user with channels
      stream = NotificationPipeline::Stream::Redis.build(store, broadcast, subscriber)
      stream.size.must_equal 2

      subscriber.snapshot.must_equal("new-songs" => 2, "new-bands" => 1) # this is for the next lookup.
      store.llen("stream:1").must_equal 2 # since we retrieved 2 items, they get persisted.
      # store.lrange("stream:1", 0, -1).collect { |ser| Marshal.load(ser) }.must_equal ""

      # refresh stream without any new messages.
      puts "next build"
      stream = NotificationPipeline::Stream::Redis.build(store, broadcast, subscriber)
      subscriber.snapshot.must_equal("new-songs" => 2, "new-bands" => 1)
      store.llen("stream:1").must_equal 2
      stream.size.must_equal 2


      # one more message.
      broadcast["new-bands"]= hsh3 = {message: "Yngwie Malmsteen"} # eat this

      stream = NotificationPipeline::Stream::Redis.build(store, broadcast, subscriber)
      subscriber.snapshot.must_equal("new-songs" => 2, "new-bands" => 2)
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

    # #flush!
    it do
      broadcast.send(:channel, "new-songs").extend(Now)

      broadcast["new-songs"]= hsh1 = {message: "Drones"}
      broadcast["new-songs"]= hsh2 = {message: "Them And Us"} # eat this
      broadcast["new-bands"]= hsh3 = {message: "Vention Dention"} # eat this

      # user with channels
      stream = NotificationPipeline::Stream::Redis.build(store, broadcast, subscriber)


      store.llen("stream:1").must_equal 2 # since we retrieved 2 items, they get persisted.
      stream.extend(NotificationPipeline::Stream::Redis::Flush).flush!
      store.llen("stream:1").must_equal 0
    end
  end


  describe "Redis+MySQL BC" do
    let (:broadcast) { NotificationPipeline::Broadcast.new.extend(NotificationPipeline::Broadcast::ActiveRecord) }
    let (:store) { Redis.new }
    before {
      store.del("stream:1")
      store.del("stream:2")
      ChannelMessage.delete_all
    }

    let (:subscriber) { NotificationPipeline::Subscriber.new(1, {"new-songs" => 1, "new-bands" => 0}) }

    # redis
    it("redis") do
      broadcast.send(:channel, "new-songs").extend(Now)


      broadcast["new-songs"]= hsh1 = {message: "Drones"}
      broadcast["new-songs"]= hsh2 = {message: "Them And Us"} # eat this
      broadcast["new-bands"]= hsh3 = {message: "Vention Dention"} # eat this

      vd = ChannelMessage.last

      # user, no channels
      stream = NotificationPipeline::Stream::Redis.build(store, broadcast, NotificationPipeline::Subscriber.new(2, {}))
      stream.size.must_equal 0


      # user with channels
      stream = NotificationPipeline::Stream::Redis.build(store, broadcast, subscriber)
      stream.size.must_equal 2

      subscriber.snapshot.must_equal("new-songs" => 2, "new-bands" => 1) # this is for the next lookup.
      store.llen("stream:1").must_equal 2 # since we retrieved 2 items, they get persisted.
      # store.lrange("stream:1", 0, -1).collect { |ser| Marshal.load(ser) }.must_equal ""

      # refresh stream without any new messages.
      puts "next build"
      stream = NotificationPipeline::Stream::Redis.build(store, broadcast, subscriber)
      subscriber.snapshot.must_equal("new-songs" => 2, "new-bands" => 1)
      store.llen("stream:1").must_equal 2
      stream.size.must_equal 2


      # one more message, only one channel.
      broadcast["new-bands"]= hsh3 = {message: "Yngwie Malmsteen"} # eat this

      stream = NotificationPipeline::Stream::Redis.build(store, broadcast, subscriber)
      subscriber.snapshot.must_equal("new-songs" => 2, "new-bands" => 2)
      store.llen("stream:1").must_equal 3
      stream.size.must_equal 3

      # stream API returns hash.
      # #[]
      # notification contains message, stream:id and created_at.
      stream[0]["message"].must_equal({"message" => "Vention Dention"})
      stream[0]["created_at"].must_equal vd.created_at
      stream[0]["id"].must_equal vd.id
      stream[0]["name"].must_equal "new-bands" # channel name
      stream[0]["stream_id"].must_equal 1


      stream[1]["message"].must_equal({"message" => "Them And Us"})
      stream[1]["id"].wont_equal stream[0]["id"]
      stream[2]["message"].must_equal({"message" => "Yngwie Malmsteen"})

      # #each
      stream.each.to_a.map{ |el| el["message"] }.must_equal [{"message"=>"Vention Dention"}, {"message"=>"Them And Us"}, {"message"=>"Yngwie Malmsteen"}]
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
      notif1 = {message: "Drones",      created_at: Now::NOW, id: hsh1.object_id, "read" => false, "stream_id" => 1},
      notif2 = {message: "Them And Us", created_at: Now::NOW, id: hsh2.object_id, "read" => false, "stream_id" => 1},
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