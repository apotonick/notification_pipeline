# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'notification_pipeline/version'

Gem::Specification.new do |spec|
  spec.name          = "notification_pipeline"
  spec.version       = NotificationPipeline::VERSION
  spec.authors       = ["Nick Sutterer"]
  spec.email         = ["apotonick@gmail.com"]
  spec.description   = %q{Generic social network notifications.}
  spec.summary       = %q{Generic social network notifications engine that allows subscribing and broadcasting notifications along with read-tracking, compression and more. It's awesome.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  # spec.add_dependency "uber"
  # spec.add_dependency "representable", "~> 2.0.3"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
  # spec.add_development_dependency "activerecord"
  # spec.add_development_dependency "sqlite3"
  # spec.add_development_dependency "database_cleaner"
end
