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

  s.homepage         = 'https://github.com/matsotaa/nis'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Andrew Matsota' => 'matsotaandrew@gmail.com' }
  s.source           = { :git => 'https://github.com/matsotaa/nis.git', :tag => s.version.to_s }
  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '12.0'
  s.tvos.deployment_target = '15.0'
  s.swift_versions = ['5.9', '5.10']
  s.module_name = 'NIS'
  s.source_files = ['Sources/NIS/**/*.swift']
  s.frameworks = ['Foundation', 'Combine', 'Security']
  s.static_framework = true
  s.requires_arc = true
end
