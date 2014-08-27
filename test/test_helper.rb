require 'notification_pipeline'
require 'minitest/autorun'


# require 'active_record'
# require 'database_cleaner'
# DatabaseCleaner.strategy = :truncation

MiniTest::Spec.class_eval do
  def self.it(name=nil, *args)
    name ||= Random.rand
    super
  end
end