require 'test_helper'

require 'ostruct'
module NotificationPipeline
  class Broadcast
    def initialize
      @channels = {}
    end

    def [](name, i=nil)
      return channel(name) unless i
      channel(name).slice(i..-1)
    end

    def channel(name)
      @channels[name] ||= Channel.new
    end
  end

  class Channel < Array
    def <<(hash)
      super Notification.new(hash)
    end
  end

  class Notification < OpenStruct

  end
end

class PipelineTest < MiniTest::Spec
  Notification = NotificationPipeline::Notification

  subject { NotificationPipeline::Broadcast.new }

  # non-existant channel.
  it { subject["non-existent", 0].must_equal [] }

  # push and read.
  it do
    subject["new-songs"] << {message: "Drones"}
    subject["new-songs", 0].must_equal [Notification.new(message: "Drones")]
  end
end