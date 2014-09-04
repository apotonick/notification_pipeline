notification_pipeline
=====================

Generic social network notifications.


Generic, but optimized for web-environment with persistence stores.


broadcast = NotificationPipeline::Broadcast.new

# publishing message to channel.
broadcast["new-songs"]= {message: "Drones"}

# subscriber
subscriber{id: 1, snapshot: {..}}

# retrieving stream for particular subscriber
stream = NotificationPipeline::Stream::Redis.build(store, subscriber, broadcast)
  # will also update subscribers snapshot.


  Architecture

  Broadcast Channel Subscriber Stream
  Per Channel persistence, e.g. Redis for high-frequency channels