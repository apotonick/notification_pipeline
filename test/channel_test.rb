require 'test_helper'

ActiveRecord::Base.establish_connection(
  :adapter => "sqlite3",
  :database => "#{Dir.pwd}/database.sqlite3"
)

# ActiveRecord::Schema.define do
#   create_table :channel_messages do |table|
#     table.column :name,    :string
#     table.column :index,   :integer
#     table.column :message, :text
#     table.timestamps
#   end
# end

class ChannelMessage < ActiveRecord::Base
  serialize :message, JSON
end

class NotificationPipeline::Channel::ActiveRecord < NotificationPipeline::Channel
  def initialize(name)
    @name = name
  end

  def [](i)
    messages = read(i)
    puts "#{i}"
    puts messages.inspect
    [messages.collect{ |msg| msg.attributes }, messages.last.index+1]
  end

private
  def persist(message)
    # TODO: wrap with transaction
    i = ChannelMessage.where(name: @name).count
    ChannelMessage.create(name: @name, message: message, index: i)
  end

  def read(i)
    ChannelMessage.where(name: @name).where("'index' >= ?", i).order("'index' ASC")
  end
end

module NotificationPipeline::Broadcast::ActiveRecord
  def build_channel(name)
    NotificationPipeline::Channel::ActiveRecord.new(name)
  end
end

class ChannelWithActiveRecordTest < MiniTest::Spec
  after do
    ChannelMessage.delete_all
  end

  class Broadcast < NotificationPipeline::Broadcast
    include ActiveRecord # Channel is ActiveRecord.
  end

  let (:broadcast) { Broadcast.new }

  it do
    ChannelMessage.count.must_equal 0

    # broadcast.send(:channel, "new-songs").must_be_kind_of NotificationPipeline::Channel::ActiveRecord

    broadcast["new-songs"] = {content: "Doin' Time"}
    broadcast["new-songs"] = {content: "Déjà Vu"}
    broadcast["new-artists"] = {content: "Van Halen"}
    ChannelMessage.count.must_equal 3
    puts "oi"
    puts ChannelMessage.where(name: "new-songs").where("'index' >= 1").to_sql.inspect

    broadcast = Broadcast.new

    messages = broadcast["new-songs" => 1]
    messages.size.must_equal 1
    messages[1]["message"].must_equal({"content"=>"Déjà Vu"})
    messages.to_hash.must_equal("new-songs" => 2)

    messages = broadcast["new-songs" => 0]
    messages.size.must_equal 2
    messages[0]["message"].must_equal({"content"=>"Doin' Time"})
    messages[1]["message"].must_equal({"content"=>"Déjà Vu"})
    messages.to_hash.must_equal("new-songs" => 2)
  end
end