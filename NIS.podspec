Pod::Spec.new do |s|
  s.name             = 'NIS'
  s.version          = '1.0.0'
  s.summary          = 'Composable networking layer for Swift'

  s.description      = <<-DESC
NIS is a modern networking layer built with Swift concurrency.

It provides:
- request adaptation
- retry strategies
- error parsing & interception
- response analysis
- in-flight deduplication
- short-lived response reuse

Designed to be composable, predictable, and production-ready.
                       DESC

  s.homepage         = 'https://github.com/YOUR_USERNAME/NIS'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Andrew Matsota' => 'your@email.com' }

  s.source           = { :git => 'https://github.com/YOUR_USERNAME/NIS.git', :tag => s.version.to_s }

  # MUST match Package.swift
  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '10.15'
  s.tvos.deployment_target = '13.0'
  s.watchos.deployment_target = '6.0'

  # Swift 6 compatible
  s.swift_versions = ['5.9', '5.10', '6.0']

  s.source_files = 'Sources/NIS/**/*.swift'

  s.requires_arc = true
end