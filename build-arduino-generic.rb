#!/usr/bin/ruby

# This program builds the Arduino project in the Current Working Directory.
# If the first argument is an existing directory, it is used instead of the CWD.

#SELF_FILE = File.expand_path __FILE__

require 'stringio'

# This will probably fail on non-Windows platforms.
# TODO: fix.
require 'win32/registry'

require './preprocess.rb'

require './localConfig.rb'
[
	:ARDUINO_SDK_DIR,
	:ARDUINO_LIB_DIR,
	:ARDUINO_COM_PORT,
].each do |const|
	if(!Module.const_defined?(const))
		raise "localConfig.rb must define #{const}"
	end
end

CExe = File.expand_path 'rules/cExe.rb'

if(ARGV[0] && Dir.exist?(ARGV[0]))
	Dir.chdir(ARGV[0])
	ARGV.delete_at(0)
end

NAME = File.basename(Dir.pwd)

require CExe

def inoFileName
	NAME+'.ino'
end

class ArduinoSourceTask < MemoryGeneratedFileTask
	def initialize
		@prerequisites = [DirTask.new('build/src')]
		super('build/src/'+inoFileName+'.cpp') do
			@buf = preprocess(IO.read(inoFileName), inoFileName)
		end
	end
end

# returns an array of FileTasks based on cwd.
def genArduinoSourceTasks
	return [ArduinoSourceTask.new]
end

BASIC_ARDUINO_IDIRS = [
	ARDUINO_SDK_DIR+'hardware/arduino/cores/arduino',
	ARDUINO_SDK_DIR+'hardware/arduino/variants/standard',
]

# returns an array of strings.
def arduinoIncludeDirctories
	patterns = {}
	idirs = BASIC_ARDUINO_IDIRS.clone
	roots = [
		ARDUINO_SDK_DIR+'libraries',
		ARDUINO_LIB_DIR,
	]
	# find directories based on .ino #includes.
	# each include must be found in only one of the idirs,
	# or its noExtName be in only one of the roots and the include be found in that dir.

	count = 0
	IO.foreach(inoFileName) do |line|
		count += 1
		res = /#include *<(.+)>/.match(line)
		if(line.include?('#include'))
			#puts line
			#puts res[1].inspect
		end
		if(res && res.length != 2)
			raise "Error parsing line #{count}"
		end
		if(res)
			include = res[1]
			found = false
			# search idirs.
			idirs.each do |idir|
				if(File.exist?(idir+'/'+include))
					found = true
					puts "Found <#{include}> in #{idir}"
					break
				end
			end

			# search roots.
			if(!found)
				roots.each do |root|
					nen = File.basename(include, File.extname(include))
					idir = root+'/'+nen
					if(File.exist?(idir) && File.exist?(idir+'/'+include))
						found = true
						puts "Found <#{include}> in #{idir}"
						idirs << idir
						# As a special addition, arduino libraries may include a "utility" subdirectory.
						# If present, this directory will be added as an include directory for that library,
						# and its source files will be compiled.
						util = idir+'/utility'
						if(Dir.exist?(util) && !patterns[idir])
							idirs << util
							patterns[Regexp.new(Regexp.escape(idir))] = idirFlags(idirs)
						end
						break
					end
				end
			end

			# searches failed.
			if(!found)
				raise "Include <#{include}> not found!"
			end
		end
	end

	return idirs, patterns
end

module GccCompilerModule
	def gcc
		ARDUINO_SDK_DIR+'hardware\tools\avr\bin\avr-gcc'
	end
	alias old_setCompilerVersion setCompilerVersion
	def setCompilerVersion
		default(:TARGET_PLATFORM, :arduino)
		old_setCompilerVersion
	end
	def linkerName
		ARDUINO_SDK_DIR+'hardware\tools\avr\bin\avr-gcc'
	end
end

def idirFlags(idirs)
	idirs.reject {|dir| BASIC_ARDUINO_IDIRS.include?(dir)}.collect {|dir| " -I\""+File.expand_path_fix(dir)+'"'}.join
end

class ArduinoWork < ExeWork
	def initialize(*a)
		@TARGET_PLATFORM == :arduino
		@SOURCE_TASKS = genArduinoSourceTasks
		@NAME = NAME

		idirs, @PATTERN_CFLAGS = arduinoIncludeDirctories
		@SPECIFIC_CFLAGS = {
			NAME+'.ino.cpp' => idirFlags(idirs),
			# work around bugs in the Arduino libs
			'HardwareSerial.cpp' => ' -Wno-sign-compare -Wno-shadow -Wno-unused -Wno-empty-body',
			'Print.cpp' => ' -Wno-attributes',
			'Tone.cpp' => ' -Wno-shadow -Wno-missing-declarations -Wno-error',
			'WMath.cpp' => ' -Wno-missing-declarations -Wno-shadow',
			'WString.cpp' => ' -Wno-missing-declarations -Wno-shadow',
			'wiring.c' => ' -Wno-old-style-definition',
			'wiring_digital.c' => ' -Wno-declaration-after-statement',
			'Dns.cpp' => ' -Wno-shadow',
		}

		@SOURCES = idirs
		@EXTRA_INCLUDES = BASIC_ARDUINO_IDIRS

		@EXTRA_LINKFLAGS = ' -Os -Wl,--gc-sections -mmcu=atmega328p'
		super
		# Once this object is properly constructed, we can create the ones that depend on it.
		elf = self
		ShellTask.new(@BUILDDIR+NAME+'.eep', [elf],
			"\"#{ARDUINO_SDK_DIR}hardware/tools/avr/bin/avr-objcopy\" -O ihex -j .eeprom --set-section-flags=.eeprom=alloc,load"+
			" --no-change-warnings --change-section-lma .eeprom=0 \"#{elf}\" \"#{@BUILDDIR+NAME+'.eep'}\"")
		@hexFile = ShellTask.new(@BUILDDIR+NAME+'.hex', [elf],
			"\"#{ARDUINO_SDK_DIR}hardware/tools/avr/bin/avr-objcopy\" -O ihex -R .eeprom \"#{elf}\" \"#{@BUILDDIR+NAME+'.hex'}\"")
	end
	def hexFile
		@hexFile
	end
	def targetName
		return CCompileTask.genFilename(@COMMON_EXE ? @COMMON_BUILDDIR : @BUILDDIR, @NAME, '.elf')
	end
end

work = ArduinoWork.new

def findDefaultComPort
	found = nil
	# This will definitely fail on non-Windows platforms.
	# TODO: fix.

	# This function is heuristical and may need modification in the future.
	# Investigation has shows that Windows stores the numbers of all active serial ports in this Registry key.
	# Arduino boards are usually connected by USB and appear to have a name starting with '\Device\USBSER'.
	# It is, as yet, unknown how far this will hold true.
	Win32::Registry::HKEY_LOCAL_MACHINE.open('HARDWARE\DEVICEMAP\SERIALCOMM') do |reg|
		reg.each do |name, type, value|
			if(name.start_with?('\Device\USBSER'))
				raise "Multiple default COM ports found! Unplug all but one, or choose manually." if(found)
				found = value
			end
		end
	end
	raise "No appropriate default COM port found! Plug in an Arduino unit, or choose manually." if(!found)
	return found
end

def selectComPort
	if(ARDUINO_COM_PORT == :default)
		return findDefaultComPort
	else
		return "COM#{ARDUINO_COM_PORT}"
	end
end

target :run do
	sh "\"#{ARDUINO_SDK_DIR}hardware/tools/avr/bin/avrdude\" \"-C#{ARDUINO_SDK_DIR}hardware/tools/avr/etc/avrdude.conf\""+
		" -V -patmega328p -carduino -P\\\\.\\#{selectComPort} -b115200 -D \"-Uflash:w:#{work.hexFile}:i\""
end

Works.run
