#!/usr/bin/ruby

# This program builds all Arduino libraries on all architectures and boards.

# todo: make sure every library is compiled at least once.

# todo: build every example.

require './arduino-libs-shared.rb'
require './localConfig.rb'

ARDUINO_ARCHITECTURES = [
	'avr/',
	'sam/',
]
optionSets = []
ARDUINO_ARCHITECTURES.each do |arch|
	boards = ArduinoBoards[ARDUINO_DEFAULT_OPTIONS[:ARDUINO_SDK_DIR], arch]
	boards.each do |k, v|
		if(v.build)
			o = ARDUINO_DEFAULT_OPTIONS.clone
			o[:ARDUINO_ARCHITECTURE_DIR] = arch
			o[:ARDUINO_BOARD] = k.to_s

			# old and broken.
			next if(o[:ARDUINO_BOARD] == 'atmegang')

			if(v.build.mcu)
				#p arch, variant
				optionSets << o
			else
				v.menu.cpu.each do |k,v|
					os = o.clone
					os[:ARDUINO_CPU] = k.to_s
					#p arch, o[:ARDUINO_BOARD], os[:ARDUINO_CPU]
					optionSets << os
				end
			end
		end
	end
end

optionSets.each do |options|
#options = optionSets[0]
#begin
	#p options
	puts "#{options[:ARDUINO_BOARD]}, #{options[:ARDUINO_CPU]}"
	LibBuilder.new(ArduinoEnvironment.new(options)).run
end

DefaultArduinoEnvironment.runArduinoWorks
