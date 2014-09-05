module NotificationPipeline
  class Channel::ActiveRecord < Channel
    def initialize(name)
      @name = name
    end

    def [](i)
      messages = read(i) # extreme costly.
      [messages.collect{ |msg| msg.attributes }, messages.last.index+1]
    end

  private
    def persist(message)
      # TODO: wrap with transaction
      i = ChannelMessage.where(name: @name).count
      ChannelMessage.create(name: @name, message: message, index: i)
    end
  end


  # Every query to Broadcast will result in one query being sent to the database checking for updates for
  # all requested channels.
  module Broadcast::ActiveRecord
    def build_channel(name)
      NotificationPipeline::Channel::ActiveRecord.new(name)
    end

    def retrieve(hash, snapshot) # we don't need to pass in channel names that haven't changed!
      ors = hash.collect do |name, last_i|
        "(name=\"#{name}\" AND \"index\" >= #{last_i})"
      end

      # SELECT "channel_messages".* FROM "channel_messages"  WHERE ((name="new-songs" AND "index" >= 1) OR (name="new-artists" AND "index" >= 1))
      messages = ChannelMessage.where(ors.join(" OR ")).order('name, "index" ASC')

      # this goes through all new messages and computes the new snapshot.
      [messages.collect { |msg| snapshot[msg.name] = msg.index+1; msg.attributes }, snapshot]
    end
  end
end