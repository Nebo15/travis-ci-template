#!/usr/bin/env ruby
require 'rubygems'
require 'xcodeproj'
require 'YAML'
require 'optparse'

# Getting arguments
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: set-codesign-settings.sh [options]"

  opts.on("-p", "--project ./PATH.xcodeproj", "Project file path") do |project_path|
    options[:project_path] = project_path
  end

  opts.on("-d", "--development_team TEAM_ID", "Development team ID. For example: 'FQ4NLM7MD5'") do |development_team|
    options[:development_team] = development_team
  end

  opts.on("-v", "--verbose", "Run verbosely") do |verbosely|
    options[:verbose] = verbosely
  end
end.parse!

if(!File.exist?(options[:project_path]))
    abort("[E] Can't find project file '" + options[:project_path] + "'.")
end

# Open the existing Xcode project
project = Xcodeproj::Project.open(options[:project_path])

# Setting DevelopmentTeam
project.root_object.attributes['TargetAttributes'].each do |target_attributes_hash|
    target_attributes_hash.each do |target_attribute|
        if(target_attribute.is_a?(Hash) && target_attribute['DevelopmentTeam'])
            puts "[I] Found target attribute DevelopmentTeam for one of targets. Current value is '" + target_attribute['DevelopmentTeam'] + "', changing it."
            target_attribute['DevelopmentTeam'] = options[:development_team]
            if(options[:verbose])
                puts '~~ [D] Target attributes (YAML):'
                puts target_attribute
            end
        end
    end
end

# Save the project file
project.save
