Pod::Spec.new do |s|
  s.name             = 'RealmStorage'
  s.version          = '2.1.0'
  s.summary          = 'A modern, actor-isolated wrapper for Realm.'

  s.description      = <<-DESC
    RealmStorage wraps Realm in an actor-isolated, async/await-only API that is
    safe under Swift 6 strict concurrency. Queries are built on Realm's native
    type-safe Query, so no code generation or build phase is required.
  DESC

  s.homepage         = 'https://github.com/AndrewKochulab/RealmStorage'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.authors          = 'Andrew Kochulab'
  s.social_media_url = 'https://github.com/AndrewKochulab'

  s.source = {
    :git => 'https://github.com/AndrewKochulab/RealmStorage.git',
    :tag => s.version.to_s
  }

  s.ios.deployment_target     = '13.0'
  s.osx.deployment_target     = '10.15'
  s.tvos.deployment_target    = '13.0'
  s.watchos.deployment_target = '6.0'

  s.cocoapods_version = '>= 1.10.0'
  s.swift_version     = '6.0'
  s.requires_arc      = true

  s.dependency 'RealmSwift', '~> 20.0'

  s.source_files = 'Sources/RealmStorage/**/*.swift'
end
