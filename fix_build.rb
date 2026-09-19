require 'xcodeproj'
project_path = "Rclone GUI.xcodeproj"
project = Xcodeproj::Project.open(project_path)
project.build_configurations.each do |config|
  config.build_settings['SWIFT_ENABLE_EXPLICIT_MODULES'] = 'NO'
  config.build_settings['ENABLE_EXPLICIT_MODULES'] = 'NO'
end
project.targets.each do |target|
  target.build_configurations.each do |config|
    config.build_settings['SWIFT_ENABLE_EXPLICIT_MODULES'] = 'NO'
    config.build_settings['ENABLE_EXPLICIT_MODULES'] = 'NO'
  end
end
project.save
