# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = 'handochogwa'
  s.version = '0.0.1'
  s.authors = ['Sangwon Yi']
  s.email = ['public@leo.re.kr']
  s.files = Dir['{lib}/**/*', 'README.md', 'LICENSE']

  s.license = 'MIT'
  s.summary = 'crawls usage data for ShinhanCard, a Korean credit card company.'
  s.description = 'Handochogwa is a rubygem that crawls Korean credit card companies'
  s.required_ruby_version = '~> 2.3'
  s.homepage = 'https://github.com/devleoper/handochogwa'

  s.add_runtime_dependency 'httpclient', '~> 2.8'
  s.add_runtime_dependency 'nokogiri', '~> 1.8'
end
