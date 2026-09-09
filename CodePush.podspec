require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name           = 'CodePush'
  s.version        = package['version'].gsub(/v|-beta/, '')
  s.summary        = package['description']
  s.author         = package['author']
  s.license        = package['license']
  s.homepage       = package['homepage']
  s.source         = { :git => 'https://github.com/bitrise-io/react-native-code-push.git', :tag => "v#{s.version}"}
  s.ios.deployment_target = '15.5'
  s.tvos.deployment_target = '15.5'
  s.preserve_paths = '*.js'
  s.libraries      = 'z', 'bz2'
  s.source_files = [
    'ios/CodePush/*.{h,m}',
    'shared/diffpatch/*.{c,h}',
    'shared/third_party/hdiffpatch/libHDiffPatch/HPatch/patch.{c,h}',
    'shared/third_party/hdiffpatch/bsdiff_wrapper/bspatch_wrapper.{c,h}',
    'shared/third_party/hdiffpatch/file_for_patch.{c,h}',
  ]
  s.public_header_files = ['ios/CodePush/CodePush.h']
  s.pod_target_xcconfig = {
    "DEFINES_MODULE" => "YES",
    # HDiffPatch's bspatch-only usage: no multithreading, no directory diff/patch, and no raw
    # block device support (which would otherwise probe Linux-only <linux/fs.h> ioctls).
    # Keep in sync with android/app/src/main/cpp/CMakeLists.txt.
    "GCC_PREPROCESSOR_DEFINITIONS" => "$(inherited) _IS_NEED_BLOCK_DEV=0 _IS_USED_MULTITHREAD=0 _IS_NEED_DIR_DIFF_PATCH=0",
    "HEADER_SEARCH_PATHS" => "$(inherited) $(PODS_TARGET_SRCROOT)/shared $(PODS_TARGET_SRCROOT)/shared/diffpatch $(PODS_TARGET_SRCROOT)/shared/third_party/hdiffpatch $(PODS_TARGET_SRCROOT)/shared/third_party/hdiffpatch/libHDiffPatch/HPatch",
  }

  # Note: Even though there are copy/pasted versions of some of these dependencies in the repo,
  # we explicitly let CocoaPods pull in the versions below so all dependencies are resolved and
  # linked properly at a parent workspace level.
  s.dependency 'React-Core'
  s.dependency 'SSZipArchive', '~> 2.5.5'
  s.dependency 'JWT', '~> 3.0.0-beta.12'
  s.dependency 'Base64', '~> 1.1'
end
