#!/usr/bin/ruby
require 'rubygems'
require 'xcodeproj'
require 'YAML'
require 'optparse'

# Getting arguments
$options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: set-codesign-settings.sh [options]"

  opts.on("-p", "--project ./PATH.xcodeproj", "Project file path") do |project_path|
    $options[:project_path] = project_path
  end

  opts.on("-t", "--target TARGET_NAME", "Target name. For example: 'MBank'") do |target|
    $options[:target] = target
  end

  opts.on("-c", "--configuration [CONFIGURATION_NAME]", "Configuration name. For example: 'Debug' or 'Release'") do |configuration|
    $options[:configuration] = configuration
  end

  opts.on("-k", "--key SETTING_NAME", "Name of the setting to search. For example: 'PROVISIONING_PROFILE'." +
                "Fill list of settings available here: http://goo.gl/lRCjBO") do |setting_key|
    $options[:setting_key] = setting_key
  end

  opts.on("-v", "--value [SETTING_VALUE]", "Value that will be set for specified setting. " +
                "You can skip this argument to read value without changing it. For example: 'iPhone Distribution: Examplecorp LLC'.") do |setting_value|
    $options[:setting_value] = setting_value
  end

  opts.on("--verbose", "Run verbosely") do |verbosely|
    $options[:verbose] = verbosely
  end
end.parse!

if(!File.exist?($options[:project_path]))
    abort("[E] Can't find project file '" + $options[:project_path] + "'.")
end

def debug_log(message)
    if($options[:verbose])
        puts message
    end
end

# Open the existing XCode project
project = Xcodeproj::Project.open($options[:project_path])

# Editing signing settings (PROVISIONING_PROFILE and CODE_SIGN_IDENTITY)
project.targets.each do |target|
    if(target.name == $options[:target])
        debug_log("[I] Found target '" + target.name + "'.")

        target.build_configurations.each do |configuration|
            if(!$options[:configuration] || configuration.name == $options[:configuration])
                debug_log("~ Found '" + configuration.name + "' build configuration.")

                if(configuration.build_settings[$options[:setting_key]])
                    if($options[:setting_value])
                        configuration.build_settings[$options[:setting_key]] = $options[:setting_value]
                    end

                    debug_log('~~ [D] Build settings (YAML):')
                    debug_log(configuration.build_settings.to_yaml)

                    prefix = ""
                    if(!$options[:configuration])
                        prefix = configuration.name + "." + $options[:setting_key] + "="
                    end
                    puts prefix + configuration.build_settings[$options[:setting_key]];
                end
            end
        end
    end
end

# Save the project file
if($options[:setting_value])
    project.save
end
