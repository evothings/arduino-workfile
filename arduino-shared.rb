selfFile = File.expand_path __FILE__
selfDir = File.dirname(selfFile)

require 'stringio'
require 'fileutils'

include FileUtils::Verbose

if(RUBY_PLATFORM =~ /win32/)
	# This fails on non-Windows platforms.
	require 'win32/registry'
end

require File.expand_path(selfDir+'/rules/cExe.rb')
require File.expand_path(selfDir+'/rules/cLib.rb')
require File.expand_path(selfDir+'/preprocess.rb')
require File.expand_path(selfDir+'/arduino-boards.rb')
require File.expand_path(selfDir+'/localConfig.rb')

SERIAL_MONITOR_PATH = "#{selfDir}/serial-monitor.rb"
BEAN_UPLOAD_PATH = "#{selfDir}/bean-upload.js"

# don't read variant, read board.
# then read boards.txt to find variant and other variables.

# Container for parsed boards.txt.
class ArduinoBoards
	# key: string, filename
	# value: BoardObject, result of parseBoardsTxt
	@@boards = {}
	def self.[](sdkDir, archDir)
		fn = sdkDir+'hardware/arduino/'+archDir+'boards.txt'
		if(!@@boards[fn])
			puts "Parsing #{fn}"
			@@boards[fn] = parseBoardsTxt(fn)
		end
		return @@boards[fn]
	end
end

class ArduinoEnvironment
REQUIRED_OPTIONS = [
	:ARDUINO_SDK_DIR,
	:ARDUINO_LIB_DIR,
	:ARDUINO_COM_PORT,
	:ARDUINO_BOARD,
	:ARDUINO_ARCHITECTURE_DIR,
]
ALLOWED_OPTIONS = [
	# Used only if BOARD doesn't specify a CPU type.
	:ARDUINO_CPU,
	:ARDUINO_CYGWIN_DIR,
	:ARDUINO_TOOLS_DIR,
]
def initialize(options)
	REQUIRED_OPTIONS.each do |key|
		if(!options[key])
			raise "ArduinoEnvironment options require #{key}"
		end
		instance_variable_set(('@'+key.to_s).to_sym, options[key])
	end
	options.each do |key, value|
		if(ALLOWED_OPTIONS.include?(key))
			instance_variable_set(('@'+key.to_s).to_sym, value)
		elsif(!REQUIRED_OPTIONS.include?(key))
			raise "ArduinoEnvironment options does not allow #{key}"
		end
	end

	boards = ArduinoBoards[@ARDUINO_SDK_DIR, @ARDUINO_ARCHITECTURE_DIR]

	@board = boards.send(@ARDUINO_BOARD)
	if(!@board)
		raise "Unknown board #{@ARDUINO_BOARD}"
	end

	@ARDUINO_VARIANT = @board.build.variant.to_s
	if(!@ARDUINO_VARIANT)
		raise "#{@ARDUINO_BOARD}.build.variant missing!"
	end

	@ARDUINO_ARCHITECTURE = archFromDir

	if(!@ARDUINO_CYGWIN_DIR)
		@ARDUINO_CYGWIN_DIR = @ARDUINO_SDK_DIR
	end

	if(!@ARDUINO_TOOLS_DIR)
		@ARDUINO_TOOLS_DIR = @ARDUINO_CYGWIN_DIR+'hardware/tools/'
	end

	@mcuSubdir = ''
	mcu = @board.build.mcu
	fcpu = @board.build.f_cpu
	mcu = nil if(@board.menu)	# atmegang
	if(!mcu && @ARDUINO_CPU)
		build = @board.menu.cpu.send(@ARDUINO_CPU).build
		mcu = build.mcu
		@mcuSubdir = @ARDUINO_CPU.to_s+'/'
		fcpu = build.f_cpu if(build.f_cpu)	# pro
	end
	if(!mcu)
		msg = "build.mcu undefined. You must choose a CPU type."
		puts msg
		puts "Available CPU types:"
		@board.menu.cpu.each do |k,v|
			puts k.to_s
		end
		raise msg
	end
	@ARDUINO_MCU = mcu.to_s
	@ARDUINO_FCPU = fcpu.to_s

	@ARDUINO_CORE_DIR = @ARDUINO_SDK_DIR+'hardware/arduino/'+@ARDUINO_ARCHITECTURE_DIR+'cores/'+@board.build.core.to_s

	@BASIC_ARDUINO_IDIRS = [
		@ARDUINO_CORE_DIR,
		@ARDUINO_SDK_DIR+'hardware/arduino/'+@ARDUINO_ARCHITECTURE_DIR+'variants/'+@ARDUINO_VARIANT,
	]

	@LIB_ROOT_DIRS = [
		@ARDUINO_SDK_DIR+'hardware/arduino/'+@ARDUINO_ARCHITECTURE_DIR+'libraries/',
		@ARDUINO_SDK_DIR+'libraries/',
		@ARDUINO_LIB_DIR,
	]

	@LIBSAM = @ARDUINO_SDK_DIR+'hardware/arduino/sam/system/libsam'
end

def mcuSubdir
	@mcuSubdir
end

def archFromDir
	case(@ARDUINO_ARCHITECTURE_DIR)
		when '', 'avr/', 'bean/'
			return :avr
		when 'sam/'
			return :sam
		else
			raise 'Unhandled architecture: '+@ARDUINO_ARCHITECTURE_DIR
	end
end

# returns an array of strings.
def arduinoIncludeDirctories(inoFileName)
	patterns = {}
	utils = []
	idirs = @BASIC_ARDUINO_IDIRS.clone
	roots = @LIB_ROOT_DIRS

	addIdir = proc do |idir|
		idirs << idir
		# As a special addition, arduino libraries may include a "utility" subdirectory.
		# If present, this directory will be added as an include directory for that library,
		# and its source files will be compiled.
		util = idir+'/utility'
		if(Dir.exist?(util))
			utils << util
			if(!patterns[idir])
				patterns[Regexp.new(Regexp.escape(idir))] = idirFlags([util])
			end
		end
	end

	# from project's settings.rb
	if(defined?(LIBRARIES))
		LIBRARIES.each do |lib|
			found = false
			roots.each do |root|
				idir = root+lib
				if(File.exist?(idir))
					found = true
					puts "Found library #{lib} in #{idir}"
					addIdir.call(idir)
					break
				end
			end
			raise "Library #{lib} not found!" if(!found)
		end
	end

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
					extensionlessName = File.basename(include, File.extname(include))
					idir = root+extensionlessName
					#puts "test #{idir}"
					if(File.exist?(idir))
						path = idir
						if(!File.exist?(idir+'/'+include))
							idir = path+'/src'
						end
						if(!File.exist?(idir+'/'+include))
							idir = path+'/source'
						end
						if(File.exist?(idir+'/'+include))
							found = true
							puts "Found <#{include}> in #{idir}"
							addIdir.call(idir)
							break
						end
					end
				end
			end

			# searches failed.
			if(!found)
				raise "Include <#{include}> not found!"
			end
		end
	end

	return idirs, utils, patterns
end

# copy instance variables, instance methods, and constants of self to reciever.
def extend_to(reciever)
	instance_variables.each do |name|
		unless(reciever.instance_variable_defined?(name))
			reciever.instance_variable_set(name, instance_variable_get(name))
		end
	end

	#self.class.extend_object(reciever)
	extender = self
	extender.class.instance_methods.each do |name|
		unless(reciever.respond_to?(name, true))
			reciever.define_singleton_method(name) do |*args|
				extender.method(name).call(*args)
			end
		end
	end

#	self.class.constants.each do |name|
#		value = self.class.const_get(name)
#		#p name, value
#		reciever.instance_eval("#{name.to_s} = #{value.inspect}")
#	end
end

ENV['CYGWIN'] = 'nodosfilewarning'

def idirFlags(idirs)
	idirs.reject {|dir| @BASIC_ARDUINO_IDIRS.include?(dir)}.collect {|dir| " -I\""+File.expand_path_fix(dir)+'"'}.join
end

def arduinoBasicIncludeDirs
	a = @BASIC_ARDUINO_IDIRS.clone
	if(@ARDUINO_ARCHITECTURE == :sam)
		a << @LIBSAM
		a << @ARDUINO_SDK_DIR+'hardware/arduino/sam/system/CMSIS/Device/ATMEL'
		a << @ARDUINO_SDK_DIR+'hardware/arduino/sam/system/CMSIS/CMSIS/Include'
	end
	return a
end

def findDefaultComPort
	found = nil
	# This will definitely fail on non-Windows platforms.
	# TODO: fix.

	if(RUBY_PLATFORM =~ /win32/)
	# This function is heuristic and may need modification in the future.
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
	end
	raise "No appropriate default COM port found! Plug in an Arduino unit, or choose manually." if(!found)
	return '\\\\.\\' + found
end

def selectComPort
	if(@ARDUINO_COM_PORT == :default)
		return findDefaultComPort
	else
		return "#{@ARDUINO_COM_PORT}"
	end
end

def runAvrdude(work)
	# Insufficient for Leonardo. See SerialUploader.java.
	sh "\"#{@ARDUINO_TOOLS_DIR}avr/bin/avrdude\" \"-C#{@ARDUINO_TOOLS_DIR}avr/etc/avrdude.conf\""+
		" -V -p#{@ARDUINO_MCU} -c#{@board.upload.protocol} -P#{selectComPort} -b#{@board.upload.speed} -D \"-Uflash:w:#{work.hexFile}:i\""
end

def runSomething(work)
	sh "node \"#{BEAN_UPLOAD_PATH}\" \"#{work.hexFile}\""
end

def uploadHexFile(work)
	if(@board.upload.protocol.to_s == 'ptdble')
		runSomething(work)
	else
		runAvrdude(work)
	end
end

def runSerialMonitor
	if(@board.upload.protocol.to_s == 'ptdble')
		return
	else
		sh "start cmd /C ruby #{SERIAL_MONITOR_PATH} #{selectComPort} 9600"
	end
end

def runArduinoWorks
	oldDir = Dir.pwd
	# This is required to access the cygwin dll files in Arduino 1.5.
	cd(@ARDUINO_CYGWIN_DIR)
	Works.run
	cd(oldDir)
end

end

class ArduinoSourceTask < MemoryGeneratedFileTask
	def initialize(inoFileName)
		@prerequisites = [DirTask.new('build/src')]
		super('build/src/'+inoFileName+'.cpp') do
			@buf = preprocess(IO.read(inoFileName), inoFileName)
		end
	end
end

module ArduinoCompilerModule
	# return a clone of this module, which, when included,
	# will extend includer with the methods and instance variables of \a environment.
	def self.withEnvironment(environment)
		c = ArduinoCompilerModule.clone
		c.class.send(:define_method, :extended) do |includer|
			#puts "#{c.class.name} extended by #{includer.class.name}."
			environment.extend_to(includer)
		end
		#p c.instance_methods
		return c
	end

	include GccCompilerModule
	def toolPrefix
		if(@ARDUINO_ARCHITECTURE == :avr)
			return 'avr/bin/avr-'
		elsif(@ARDUINO_ARCHITECTURE == :sam)
			return 'gcc-arm-none-eabi-4.8.3-2014q1/bin/arm-none-eabi-'
		else
			raise 'Unhandled architecture: '+@ARDUINO_ARCHITECTURE
		end
	end
	def gcc
		@ARDUINO_TOOLS_DIR+toolPrefix+'gcc'
	end
	alias old_setCompilerVersion setCompilerVersion
	def setCompilerVersion
		default(:TARGET_PLATFORM, :arduino)
		oldDir = Dir.pwd
		# This is required to access the cygwin dll files in Arduino 1.5.
		Dir.chdir(@ARDUINO_CYGWIN_DIR)
		old_setCompilerVersion
		Dir.chdir(oldDir)
	end
	def linkerName
		@ARDUINO_TOOLS_DIR+toolPrefix+'gcc'
	end
	def objCopyName
		@ARDUINO_TOOLS_DIR+toolPrefix+'objcopy'
	end
	def moduleTargetFlags
		build = @board.build
		bef = build.extra_flags.to_s.gsub("{build.usb_flags}", "")
		raise hell if(!@ARDUINO_FCPU)
		shared = " -fno-exceptions -ffunction-sections -fdata-sections"+
			" -DF_CPU=#{@ARDUINO_FCPU} -DARDUINO=157 -DARDUINO_#{build.board} "+bef+
			" -DUSB_VID=#{build.vid} -DUSB_PID=#{build.pid}"
		if(@ARDUINO_ARCHITECTURE == :avr)
			return shared+" -DARDUINO_ARCH_AVR -mmcu=#{@ARDUINO_MCU}"
		elsif(@ARDUINO_ARCHITECTURE == :sam)
			return shared+" -DARDUINO_ARCH_SAM -mcpu=#{@ARDUINO_MCU} -nostdlib --param max-inline-insns-single=500"+
				" -Dprintf=iprintf"+
				"  -DUSBCON -DUSB_MANUFACTURER=\"Unknown\" -DUSB_PRODUCT=#{build.usb_product}"
		else
			raise 'Unhandled architecture: '+@ARDUINO_ARCHITECTURE
		end
	end
	def moduleTargetCFlags
		' -Wno-c++-compat'
	end
	def moduleTargetCppFlags
		' -fno-rtti -std=c++0x'
	end
end

class ArduinoHexWork < ExeWork
	def initialize(environment = DefaultArduinoEnvironment)
		@TARGET_PLATFORM = :arduino
		super(ArduinoCompilerModule.withEnvironment(environment)) do
		@NAME = NAME
		@SOURCE_TASKS = genArduinoSourceTasks

		idirs, utils, @PATTERN_CFLAGS = arduinoIncludeDirctories(inoFileName)
		@SPECIFIC_CFLAGS = {
			NAME+'.ino.cpp' => idirFlags(idirs + [Dir.pwd]),
			'BeanSerialTransport.cpp' => ' -Wno-vla -Wno-shadow -Wno-suggest-attribute=noreturn',
			'HardwareSerial.cpp' => ' -Wno-sign-compare -Wno-shadow -Wno-unused -Wno-empty-body',
			'HardwareSerial0.cpp' => ' -Wno-missing-declarations',
			'Print.cpp' => ' -Wno-attributes',
			'Tone.cpp' => ' -Wno-shadow -Wno-missing-declarations -Wno-error',
			'WMath.cpp' => ' -Wno-missing-declarations -Wno-shadow',
			'WString.cpp' => ' -Wno-missing-declarations -Wno-shadow',
			'wiring.c' => ' -Wno-old-style-definition',
			'wiring_digital.c' => ' -Wno-declaration-after-statement',
			'Dns.cpp' => ' -Wno-shadow -fno-strict-aliasing',
			'Dhcp.cpp' => ' -Wno-shadow -fno-strict-aliasing -Wstrict-aliasing=0',
			'EthernetUdp.cpp' => ' -Wno-shadow',
			'socket.cpp' => ' -Wno-unused-but-set-variable',
			'WiFi.cpp' => ' -Wno-shadow -Wno-undef',
			'WiFiClient.cpp' => ' -Wno-undef',
			'WiFiServer.cpp' => ' -Wno-shadow -Wno-undef',
			'WiFiUdp.cpp' => ' -Wno-shadow -Wno-undef',
			'server_drv.cpp' => ' -Wno-undef',
			'spi_drv.cpp' => ' -Wno-missing-declarations -Wno-undef -Wno-error',
			'wifi_drv.cpp' => ' -Wno-type-limits -Wno-extra -Wno-undef',
			'Stream.cpp' => ' -Wno-write-strings',
			'hooks.c' => ' -Wno-strict-prototypes -Wno-old-style-definition',
			'acilib.cpp' => ' -Wno-switch',
			'lib_aci.cpp' => ' -Wno-missing-declarations',
			'RBL_nRF8001.cpp' => ' -Wno-missing-declarations -Wno-switch',
		}

		@SOURCES = idirs + utils + [Dir.pwd]
		@EXTRA_INCLUDES = arduinoBasicIncludeDirs + idirs

		if(defined?(SOURCES))
			@SOURCES += SOURCES
			@SPECIFIC_CFLAGS[NAME+'.ino.cpp'] += idirFlags(SOURCES)
		end

		if(defined?(SOURCE_TASKS))
			@SOURCE_TASKS += SOURCE_TASKS
		end

		@EXTRA_LINKFLAGS = " -Os -Wl,--gc-sections -mmcu=#{@ARDUINO_MCU}"

		if(defined?(HEX_OPTIONS))
			HEX_OPTIONS.each do |key, value|
				instance_variable_set('@'+key.to_s, value)
			end
		end

		end	# super.do
		# Once this object is properly constructed, we can create the ones that depend on it.
		elf = self
		ShellTask.new(@BUILDDIR+NAME+'.eep', [elf],
			"\"#{objCopyName}\" -O ihex -j .eeprom --set-section-flags=.eeprom=alloc,load"+
			" --no-change-warnings --change-section-lma .eeprom=0 \"#{elf}\" \"#{@BUILDDIR+NAME+'.eep'}\"")
		@hexFile = ShellTask.new(@BUILDDIR+NAME+'.hex', [elf],
			"\"#{objCopyName}\" -O ihex -R .eeprom \"#{elf}\" \"#{@BUILDDIR+NAME+'.hex'}\"")

		# TODO: Output amount of used memory.
		# If a program uses too much memory, it will crash.
		#ShellTask.new('avr-size', -A, elf)
	end
	def hexFile
		@hexFile
	end
	def targetName
		return CCompileTask.genFilename(@COMMON_EXE ? @COMMON_BUILDDIR : @BUILDDIR, @NAME, '.elf')
	end

	def inoFileName
		@NAME+'.ino'
	end

	# returns an array of FileTasks based on cwd.
	def genArduinoSourceTasks
		return [ArduinoSourceTask.new(inoFileName)]
	end
end

class ArduinoLibWork < LibWork
	def initialize(environment = DefaultArduinoEnvironment, &block)
		@TARGET_PLATFORM = :arduino
		super(ArduinoCompilerModule.withEnvironment(environment)) do
			@EXTRA_INCLUDES = arduinoBasicIncludeDirs
			instance_eval(&block) if(block)
		end
	end
end

DefaultArduinoEnvironment = ArduinoEnvironment.new(ARDUINO_DEFAULT_OPTIONS)
