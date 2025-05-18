# -*- encoding: utf-8 -*-
# stub: aasm 5.5.0 ruby lib

Gem::Specification.new do |s|
  s.name = "aasm".freeze
  s.version = "5.5.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Thorsten Boettger".freeze, "Anil Maurya".freeze]
  s.date = "2023-02-05"
  s.description = "AASM is a continuation of the acts-as-state-machine rails plugin, built for plain Ruby objects.".freeze
  s.email = "aasm@mt7.de, anilmaurya8dec@gmail.com".freeze
  s.homepage = "https://github.com/aasm/aasm".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3".freeze)
  s.rubygems_version = "3.0.9".freeze
  s.summary = "State machine mixin for Ruby objects".freeze

  s.installed_by_version = "3.6.3".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<concurrent-ruby>.freeze, ["~> 1.0".freeze])
  s.add_development_dependency(%q<rake>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<sdoc>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rspec>.freeze, [">= 3".freeze])
  s.add_development_dependency(%q<generator_spec>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<appraisal>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<simplecov>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<codecov>.freeze, [">= 0.1.21".freeze])
  s.add_development_dependency(%q<pry>.freeze, [">= 0".freeze])
end
