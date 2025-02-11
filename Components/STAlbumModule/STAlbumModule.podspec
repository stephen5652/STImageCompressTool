Pod::Spec.new do |spec|

  spec.name         = "STAlbumModule"
  spec.version      = "0.0.1"
  spec.summary      = "STAlbumModule 说明."
  spec.description      = <<-DESC
  STAlbumModule long description of the pod here.
  DESC

  spec.homepage         = 'http://github.com/StephenChen/STAlbumModule'
  spec.license      = { :type => "MIT", :file => "FILE_LICENSE" }
  spec.author             = { "StephenChen" => "stephen.chen@hellotalk.cn" }
  spec.ios.deployment_target = '13.0'

  spec.source       = { :git => "http://github/StephenChen/STAlbumModule.git", :tag => "#{spec.version}" }


  # ――― Source Code ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  spec.source_files = 'STAlbumModule/{Public,Private}/**/*.{h,m,mm,c,cpp,swift}'
  # spec.exclude_files = "STAlbumModule/Exclude" #排除文件

  spec.project_header_files = 'STAlbumModule/Private/**/*.{h}'
  spec.public_header_files = 'STAlbumModule/Public/**/*.h' #此处放置组件的对外暴漏的头文件

  # ――― binary framework/lib ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #spec.vendored_frameworks = 'STAlbumModule/Private/**/*.framework'
  #spec.vendored_libraries = 'STAlbumModule/Private/**/*.a'

  # ――― Resources ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  # 放置 json,font,jpg,png等资源
  #  spec.resources = ["STAlbumModule/{Public,Private}/**/*.{xib}"]
  #  spec.resource_bundles = {
  #    'STAlbumModule' => ['STAlbumModule/Assets/*.xcassets', "STAlbumModule/{Public,Private}/**/*.{png,jpg,font,json}"]
  #  }


  # ――― Project Linking ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  # spec.framework  = "SomeFramework"
  # spec.frameworks = "SomeFramework", "AnotherFramework"
  # spec.library   = "iconv"
  # spec.libraries = "iconv", "xml2"


  # ――― Project Settings ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  # spec.requires_arc = true

  # spec.xcconfig = { "HEADER_SEARCH_PATHS" => "$(SDKROOT)/usr/include/libxml2" }

  # 其他依赖pod
  # spec.dependency "XXXXXXXX"

#   spec.subspec 'WithLoad' do |ss|
#       ss.source_files = 'YKHawkeye/Src/MethodUseTime/**/*{.h,.m}'
#       ss.pod_target_xcconfig = {
#         'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) YKHawkeyeWithLoad'
#       }
#       ss.dependency 'YKHawkeye/Core'
#       ss.vendored_frameworks = 'YKHawkeye/Framework/*.framework'
#     end

spec.dependency "STComponentTools/STRouter"
spec.dependency "STModuleService.swift"  #swift 服务中间件
spec.dependency 'STAllBase'
end
