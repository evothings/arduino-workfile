#!/usr/bin/ruby

# This program builds the Arduino project in the Current Working Directory.
# If the first argument is an existing directory, it is used instead of the CWD.

require './arduino-shared.rb'

work = ArduinoHexWork.new

target :run do
	runAvrdude(work)
end

runArduinoWorks
