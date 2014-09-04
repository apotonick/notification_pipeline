module NotificationPipeline
  Subscriber = Struct.new(:id, :snapshot)
end

require 'notification_pipeline/broadcast'
require "notification_pipeline/stream"