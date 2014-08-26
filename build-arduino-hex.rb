#!/usr/bin/ruby

# This program builds the Arduino project in the Current Working Directory.
# If the first argument is an existing directory, it is used instead of the CWD.

AS = File.dirname(File.expand_path __FILE__)+'/arduino-shared.rb'

if(ARGV[0] && Dir.exist?(ARGV[0]))
	Dir.chdir(ARGV[0])
	ARGV.delete_at(0)
end

NAME = File.basename(Dir.pwd)

if(File.exist?('settings.rb'))
	require './settings.rb'
end

require AS

work = ArduinoHexWork.new

DefaultArduinoEnvironment.extend_to(self)

target :run do
	runAvrdude(work)
end

runArduinoWorks
