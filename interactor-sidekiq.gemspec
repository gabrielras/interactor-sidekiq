# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'interactor/sidekiq/version'

Gem::Specification.new do |spec|
  spec.name          = 'interactor-sidekiq'
  spec.version       = Interactor::Sidekiq::VERSION
  spec.authors       = ['Gabriel Rocha']
  spec.email         = ['gabrielras100@gmail.com']
  spec.summary       = 'Async Interactor using Sidekiq'
  spec.description   = 'Async Interactor using Sidekiq'
  spec.homepage      = 'https://github.com/gabrielras/interactor-sidekiq'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'interactor', '~> 3.0'
  spec.add_dependency 'sidekiq', '>=4.1'
end
