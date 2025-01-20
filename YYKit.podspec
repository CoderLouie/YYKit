Pod::Spec.new do |s|
  s.name         = 'YYKit'
  s.summary      = 'A collection of iOS components.'
  s.version      = '1.0.9'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.authors      = { 'ibireme' => 'ibireme@gmail.com' }
  s.social_media_url = 'http://blog.ibireme.com'
  s.homepage     = 'https://github.com/ibireme/YYKit'
  s.platform     = :ios, '6.0'
  s.ios.deployment_target = '6.0'
  s.source       = { :git => 'https://github.com/ibireme/YYKit.git', :tag => s.version.to_s }
  
  s.requires_arc = true
  s.default_subspec = 'Core'

  non_arc_files = 'YYKit/Base/Foundation/NSObject+YYAddForARC.{h,m}', 'YYKit/Base/Foundation/NSThread+YYAdd.{h,m}'
  
  s.subspec 'no-arc' do |sna|
    sna.requires_arc = false
    sna.source_files = non_arc_files
  end

  s.subspec 'Core' do |core|
    core.dependency 'YYKit/no-arc'
    core.source_files = 'YYKit/**/*.{h,m}'
    core.public_header_files = 'YYKit/**/*.{h}'
    core.ios.exclude_files = non_arc_files
    core.libraries = 'z', 'sqlite3'
    core.frameworks = 'UIKit', 'CoreFoundation', 'CoreText', 'CoreGraphics', 'CoreImage', 'QuartzCore', 'ImageIO', 'AssetsLibrary', 'Accelerate', 'MobileCoreServices', 'SystemConfiguration'
  end

  s.subspec 'WebP' do |webp|
    webp.dependency 'YYKit/Core'
    webp.ios.vendored_frameworks = 'Vendor/WebP.framework'
  end

end
