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
stream, new_snapshot = NotificationPipeline::Stream::Redis.build(store, 1, broadcast, new_snapshot)
stream = NotificationPipeline::Stream::Redis.build(store, subscriber, broadcast)