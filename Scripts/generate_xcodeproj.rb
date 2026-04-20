#!/usr/bin/env ruby

require 'fileutils'
require 'pathname'
require 'rubygems'

ROOT = Pathname.new(__dir__).join("..").expand_path
PROJECT_PATH = ROOT.join("AdmitPath.xcodeproj")
APP_ROOT = ROOT.join("AdmitPath")
TEST_ROOT = ROOT.join("Tests", "AdmitPathLogicTests")
UI_TEST_ROOT = ROOT.join("UITests", "AdmitPathUITests")
APP_INFO_PLIST = ROOT.join("AdmitPath", "Support", "AdmitPath-Info.plist")

def configure_gems
  cocoapods_libexec = Dir["/opt/homebrew/Cellar/cocoapods/*/libexec"].max
  return unless cocoapods_libexec

  default_paths = [
    File.expand_path("~/.local/share/gem/ruby/4.0.0"),
    "/opt/homebrew/lib/ruby/gems/4.0.0",
    "/opt/homebrew/Cellar/ruby/4.0.2/lib/ruby/gems/4.0.0"
  ]

  Gem.use_paths(cocoapods_libexec, [cocoapods_libexec, *default_paths, *Gem.path].uniq)
end

configure_gems
require 'xcodeproj'

def add_files(group, directory, target:, include_resources: false)
  directory.children.sort.each do |path|
    if path.extname == ".xcassets"
      file_ref = group.new_file(path.to_s)
      target.resources_build_phase.add_file_reference(file_ref, true)
      next
    end

    if path.directory?
      subgroup = group.find_subpath(path.basename.to_s, true)
      subgroup.set_source_tree("<group>")
      add_files(subgroup, path, target: target, include_resources: include_resources)
      next
    end

    next unless path.file?

    extension = path.extname
    next unless [".swift", ".json"].include?(extension)

    file_ref = group.new_file(path.to_s)
    case extension
    when ".swift"
      target.add_file_references([file_ref])
    when ".json", ".xcassets"
      target.resources_build_phase.add_file_reference(file_ref, true)
    end
  end
end

FileUtils.rm_rf(PROJECT_PATH.to_s)
project = Xcodeproj::Project.new(PROJECT_PATH.to_s)
project.root_object.attributes["LastUpgradeCheck"] = "1600"
project.root_object.attributes["TargetAttributes"] ||= {}

app_target = project.new_target(:application, "AdmitPath", :ios, "17.0")
test_target = project.new_target(:unit_test_bundle, "AdmitPathTests", :ios, "17.0")
ui_test_target = project.new_target(:ui_test_bundle, "AdmitPathUITests", :ios, "17.0")
test_target.add_dependency(app_target)
ui_test_target.add_dependency(app_target)

[
  app_target,
  test_target,
  ui_test_target
].each do |target|
  target.build_configurations.each do |config|
    config.build_settings["SWIFT_VERSION"] = "5.0"
    config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "17.0"
    config.build_settings["CODE_SIGN_STYLE"] = "Automatic"
    config.build_settings["DEVELOPMENT_TEAM"] = ""
    config.build_settings["CODE_SIGNING_ALLOWED[sdk=iphonesimulator*]"] = "NO"
    config.build_settings["CODE_SIGNING_REQUIRED[sdk=iphonesimulator*]"] = "NO"
    config.build_settings["CODE_SIGNING_ALLOWED[sdk=macosx*]"] = "NO"
    config.build_settings["CODE_SIGNING_REQUIRED[sdk=macosx*]"] = "NO"
    config.build_settings["GENERATE_INFOPLIST_FILE"] = target == app_target ? "NO" : "YES"
    config.build_settings["ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS"] = "YES"
    case target
    when app_target
      config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.admitpath.demo"
      config.build_settings["PRODUCT_BUNDLE_IDENTIFIER[sdk=macosx*]"] = "com.admitpath.demo.catalyst"
    when test_target
      config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.admitpath.demo.tests"
    when ui_test_target
      config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.admitpath.demo.uitests"
    end
    config.build_settings["TARGETED_DEVICE_FAMILY"] = "1,2"
    config.build_settings["SUPPORTS_MACCATALYST"] = "YES"
    config.build_settings["CURRENT_PROJECT_VERSION"] = "1"
    config.build_settings["MARKETING_VERSION"] = "1.0"
  end
end

app_target.build_configurations.each do |config|
  config.build_settings["INFOPLIST_FILE"] = APP_INFO_PLIST.to_s
  config.build_settings["INFOPLIST_KEY_UIApplicationSceneManifest_Generation"] = "YES"
  config.build_settings["INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents"] = "YES"
  config.build_settings["INFOPLIST_KEY_UILaunchScreen_Generation"] = "YES"
  config.build_settings["INFOPLIST_KEY_UIStatusBarStyle"] = "UIStatusBarStyleDefault"
  config.build_settings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"
  config.build_settings["SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD"] = "NO"
  config.build_settings["LD_RUNPATH_SEARCH_PATHS"] = ["$(inherited)", "@executable_path/Frameworks"]
end

test_target.build_configurations.each do |config|
  config.build_settings["TEST_HOST"] = "$(BUILT_PRODUCTS_DIR)/AdmitPath.app/AdmitPath"
  config.build_settings["BUNDLE_LOADER"] = "$(TEST_HOST)"
end

ui_test_target.build_configurations.each do |config|
  config.build_settings["TEST_TARGET_NAME"] = "AdmitPath"
end

app_group = project.main_group.find_subpath("AdmitPath", true)
app_group.set_source_tree("<group>")
test_group = project.main_group.find_subpath("Tests", true)
test_group.set_source_tree("<group>")
ui_test_group = project.main_group.find_subpath("UITests", true)
ui_test_group.set_source_tree("<group>")

add_files(app_group, APP_ROOT, target: app_target, include_resources: true)
add_files(test_group, TEST_ROOT, target: test_target, include_resources: false)
add_files(ui_test_group, UI_TEST_ROOT, target: ui_test_target, include_resources: false)

project.save

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app_target)
scheme.add_build_target(test_target, false)
scheme.add_build_target(ui_test_target, false)
scheme.set_launch_target(app_target)
scheme.add_test_target(test_target)
scheme.add_test_target(ui_test_target)
scheme.save_as(PROJECT_PATH.to_s, "AdmitPath", true)

puts "Generated #{PROJECT_PATH}"
