#!/usr/bin/ruby

# This program builds all Arduino libraries on all architectures and variants.

# todo: test every architecture and variant.
# make sure every library is compiled at least once.

# todo: build every example.

require './arduino-libs-shared.rb'
require './localConfig.rb'

ARDUINO_ARCHITECTURES = [
	'avr/',
	'sam/',
]
optionSets = []
ARDUINO_ARCHITECTURES.each do |arch|
	vDir = ARDUINO_DEFAULT_OPTIONS[:ARDUINO_SDK_DIR]+'hardware/arduino/'+arch+'variants/'
	Dir.entries(vDir).each do |variant|
		if(!variant.start_with?('.') && Dir.exist?(vDir+variant))
			o = ARDUINO_DEFAULT_OPTIONS.clone
			o[:ARDUINO_ARCHITECTURE_DIR] = arch
			o[:ARDUINO_VARIANT] = variant
			#p arch, variant
			optionSets << o
		end
	end
end

optionSets.each do |options|
#options = optionSets[0]
#begin
	#p options
	LibBuilder.new(ArduinoEnvironment.new(options)).run
end

DefaultArduinoEnvironment.runArduinoWorks
