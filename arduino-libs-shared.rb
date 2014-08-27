#!/usr/bin/ruby

# Common code for building Arduino libraries.

require File.dirname(File.expand_path __FILE__)+'/arduino-shared.rb'

class LibBuilder
	def initialize(environment)
		@environment = environment
		environment.extend_to(self)
	end

	def run
# not indented for legacy source control reasons.

libDirs = [@ARDUINO_CORE_DIR]
@LIB_ROOT_DIRS.each do |root|
	Dir.foreach(root) do |dir|
		if(Dir.exist?(root+dir) && !dir.start_with?('.'))
			libDirs << root+dir
		end
	end if(Dir.exist?(root))
end

if(@ARDUINO_ARCHITECTURE == :sam)
	libDirs << @LIBSAM
end

works = []
libDirs.each do |path|
	# read library.properties, check that "architectures" matches.
	architectureMatches = true
	libDeps = []
	open(path+'/library.properties') do |file|
		archLineFound = false
		depLineFound = false
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
					if(@ARDUINO_ARCHITECTURE == la.to_sym)
						architectureMatches = true
						break
					end
					architectureMatches = false
					#p path, la
				end
			end
			a = 'dependencies='
			if(line.start_with?(a))
				raise hell if(depLineFound)
				depLineFound = true
				libDeps = line[a.length..-1].strip.split(',')
			end
		end
	end if(File.exist?(path+'/library.properties'))

	next if(!architectureMatches)

	# check certain hard-coded limitations
	name = File.basename(path)
	if(name == 'Esplora')
		# Esplora requires pin A11, available only on these variants.
		next unless(@ARDUINO_VARIANT == 'mega' || @ARDUINO_VARIANT == 'leonardo')
	end
	if(name == 'RobotIRremote' || name == 'Robot_Control')
		next unless(@ARDUINO_VARIANT == 'robot_control')
	end
	if(name == 'Robot_Motor')
		next unless(@ARDUINO_VARIANT == 'robot_motor')
	end
	if(name == 'SpacebrewYun')
		next unless(@ARDUINO_VARIANT == 'yun')
	end
	if(name == 'GSM')
		# GSM3SoftSerial.cpp doesn't yet support this CPU.
		next if(@ARDUINO_MCU == 'atmega168')
	end
	if(@ARDUINO_VARIANT == 'robot_control' || @ARDUINO_VARIANT == 'robot_motor')
		# robot_control/pins_arduino.h doesn't supply digitalPinToPCICR().
		next if(name == 'SoftwareSerial' || name == 'GSM')
	end
	# Undocumented limitation: BLE libs require avr headers.
	if((name == 'RBL_nRF8001' || name == 'BLE'))
		next unless(@ARDUINO_ARCHITECTURE == :avr)
	end

	works << ArduinoLibWork.new(@environment) do
		@NAME = name
		@BUILDDIR_PREFIX = @ARDUINO_ARCHITECTURE_DIR+@ARDUINO_BOARD+'/'+mcuSubdir+name+'/'
		#p name

		src = path+'/src'
		if(!Dir.exist?(src))
			src = path+'/source'
		end
		if(!Dir.exist?(src))
			src = path
		end
		@SOURCES = [src]

		util = src+'/utility'
		@SOURCES << util if(Dir.exist?(util))

		arch = src+'/'+@ARDUINO_ARCHITECTURE.to_s
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
				@EXTRA_INCLUDES << @ARDUINO_SDK_DIR+'hardware/arduino/'+@ARDUINO_ARCHITECTURE_DIR+'libraries/'+lib
			end
		end

		libDeps.each do |lib|
			@EXTRA_INCLUDES << @ARDUINO_SDK_DIR+'libraries/'+lib+'/src'
		end

		# hard-coded extras
		if(name == 'RBL_nRF8001')
			@EXTRA_INCLUDES << @ARDUINO_LIB_DIR+'BLE'
		end
		if(name == 'libsam')
			@EXTRA_INCLUDES << path+'/include'
			@SPECIFIC_CFLAGS = {
				'emac.c' => ' -Wno-maybe-uninitialized',	# compiler bug
			}
		end
	end
end

# legacy indent end
	end
end
