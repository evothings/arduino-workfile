#!/usr/bin/ruby

# This program builds the Arduino project in the Current Working Directory.
# If the first argument is an existing directory, it is used instead of the CWD.

require './arduino-shared.rb'

libDirs = [ARDUINO_CORE_DIR]
LIB_ROOT_DIRS.each do |root|
	Dir.foreach(root) do |dir|
		if(Dir.exist?(root+dir) && !dir.start_with?('.'))
			libDirs << root+dir
		end
	end
end

works = []
libDirs.each do |path|
	# read library.properties, check that "architectures" matches.
	architectureMatches = true
	open(path+'/library.properties') do |file|
		archLineFound = false
		file.each do |line|
			a = 'architectures='
			if(line.start_with?(a))
				raise hell if(archLineFound)
				archLineFound = true
				libArches = line[a.length..-1].strip.split(',')
				libArches.each do |la|
					if(la == '*')
						raise hell if(libArches.length != 1)
						break
					end
					if(ARDUINO_ARCHITECTURE.start_with?(la))
						architectureMatches = true
						break
					end
					architectureMatches = false
					p path, la
				end
			end
		end
	end if(File.exist?(path+'/library.properties'))

	next if(!architectureMatches)

	# check certain hard-coded limitations
	name = File.basename(path)
	if(name == 'Esplora')
		# Esplora requires pin A11, available only on these variants.
		next unless(ARDUINO_VARIANT == 'mega' || ARDUINO_VARIANT == 'leonardo')
	end
	if(name == 'RobotIRremote' || name == 'Robot_Control')
		next unless(ARDUINO_VARIANT == 'robot_control')
	end
	if(name == 'Robot_Motor')
		next unless(ARDUINO_VARIANT == 'robot_motor')
	end
	if(name == 'SpacebrewYun')
		next unless(ARDUINO_VARIANT == 'yun')
	end

	works << ArduinoLibWork.new do
		@NAME = name
		@BUILDDIR_PREFIX = ARDUINO_ARCHITECTURE+name+'/'
		#p name

		src = path+'/src'
		if(!Dir.exist?(src))
			src = path
		end
		@SOURCES = [src]

		util = src+'/utility'
		@SOURCES << util if(Dir.exist?(util))

		arch = src+'/'+ARDUINO_ARCHITECTURE
		@SOURCES << arch if(Dir.exist?(arch))

		@EXTRA_INCLUDES += @SOURCES
		@EXTRA_CPPFLAGS = ' -Wno-vla'

		# core library dependencies
		coreDependencies = {
			'Ethernet' => ['SPI'],
			'WiFi' => ['SPI'],
			'Robot_Control' => ['SPI', 'Wire'],
			'SD' => ['SPI'],
			'TFT' => ['SPI'],
			'BLE' => ['SPI'],
			'RBL_nRF8001' => ['SPI'],
		}
		libs = coreDependencies[name]
		if(libs)
			libs.each do |lib|
				@EXTRA_INCLUDES << ARDUINO_SDK_DIR+'hardware/arduino/'+ARDUINO_ARCHITECTURE+'libraries/'+lib
			end
		end

		# hard-coded extras
		if(ARDUINO_ARCHITECTURE.start_with?('avr'))
			@EXTRA_CPPFLAGS << ' -DARDUINO_ARCH_AVR'
		end

		if(name == 'RBL_nRF8001')
			@EXTRA_INCLUDES << ARDUINO_LIB_DIR+'BLE'
		end
	end
end

# todo: test every architecture and variant.
# make sure every library is compiled at least once.

runArduinoWorks
