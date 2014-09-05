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

    def read(i)
      ChannelMessage.where(name: @name).where('"index" >= ?', i).order("'index' ASC")
    end
  end


  module Broadcast::ActiveRecord
    def build_channel(name)
      NotificationPipeline::Channel::ActiveRecord.new(name)
    end
  end
end