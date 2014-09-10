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
# add_index :channel_messages, [:name, :index]

class ChannelMessage < ActiveRecord::Base
  serialize :message, JSON
end

require 'notification_pipeline/active_record'

class ChannelWithActiveRecordTest < MiniTest::Spec
  before do
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
    broadcast["new-artists"] = {content: "Van Halen"} # 0
    broadcast["new-artists"] = {content: "Helloween"} # 1
    broadcast["new-artists"] = {content: "Rainbow"}   # 2
    ChannelMessage.count.must_equal 5
    persisted = ChannelMessage.all.order(:id)

    broadcast = Broadcast.new

    messages = broadcast["new-songs" => 1, "new-artists" => 0]
    messages.size.must_equal 4
    # puts messages.inspect

    # message contains created_at and id.
    messages[0].must_equal("message" => {"content"=>"Van Halen"}, "id" => persisted[2].id, "created_at" => persisted[2].created_at, "name"=> "new-artists", "index"=>0)
    messages[1]["message"].must_equal({"content"=>"Helloween"})
    messages[2]["message"].must_equal({"content"=>"Rainbow"})
    messages[3]["message"].must_equal({"content"=>"Déjà Vu"})
    messages.to_hash.must_equal("new-songs" => 2, "new-artists" => 3)

    messages = broadcast["new-songs" => 0]
    messages.size.must_equal 2
    messages[0]["message"].must_equal({"content"=>"Doin' Time"})
    messages[1]["message"].must_equal({"content"=>"Déjà Vu"})
    messages.to_hash.must_equal("new-songs" => 2)

    # retrieve non-existent messages
    messages = broadcast["new-songs" => 2]
    messages.size.must_equal 0
  end
end