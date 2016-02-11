# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fleck/version'

Gem::Specification.new do |spec|
  spec.name          = "fleck"
  spec.platform      = "ruby"
  spec.version       = Fleck::VERSION
  spec.authors       = ["Groza Sergiu"]
  spec.email         = ["serioja90@gmail.com"]

  spec.summary       = %q{A Ruby gem for syncronous and asyncronous communication via Message Queue services.}
  spec.description   = %q{
    Fleck is a library for syncronous and asyncronous communication over Message Queues services. Unlike a common
    HTTP communication, Fleck requests and responses are pure JSON messages.
  }
  spec.homepage      = "https://github.com/serioja90/fleck"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = "~> 2.0"

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3"
  spec.add_dependency             "rainbow", "~> 2.0"
  spec.add_dependency             "bunny", "~> 2.2"
  spec.add_dependency             "thread_safe", "~> 0.3"
  spec.add_dependency             "oj", "~> 2.14"
end
