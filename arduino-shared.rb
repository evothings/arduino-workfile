selfFile = File.expand_path __FILE__
selfDir = File.dirname(selfFile)

require 'stringio'
require 'fileutils'

include FileUtils::Verbose

# This will probably fail on non-Windows platforms.
# TODO: fix.
require 'win32/registry'

require File.expand_path(selfDir+'/rules/cExe.rb')
require File.expand_path(selfDir+'/rules/cLib.rb')
require File.expand_path(selfDir+'/preprocess.rb')
require File.expand_path(selfDir+'/localConfig.rb')

class ArduinoEnvironment
REQUIRED_OPTIONS = [
	:ARDUINO_SDK_DIR,
	:ARDUINO_LIB_DIR,
	:ARDUINO_COM_PORT,
	:ARDUINO_VARIANT,
	:ARDUINO_ARCHITECTURE_DIR,
]
ALLOWED_OPTIONS = [
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

	@ARDUINO_ARCHITECTURE = archFromDir

	if(!@ARDUINO_CYGWIN_DIR)
		@ARDUINO_CYGWIN_DIR = @ARDUINO_SDK_DIR
	end

	if(!@ARDUINO_TOOLS_DIR)
		@ARDUINO_TOOLS_DIR = @ARDUINO_CYGWIN_DIR+'hardware/tools/'
	end

	@ARDUINO_CORE_DIR = @ARDUINO_SDK_DIR+'hardware/arduino/'+@ARDUINO_ARCHITECTURE_DIR+'cores/arduino'

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

def archFromDir
	case(@ARDUINO_ARCHITECTURE_DIR)
		when '', 'avr/'
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
					if(File.exist?(idir) && File.exist?(idir+'/'+include))
						found = true
						puts "Found <#{include}> in #{idir}"
						addIdir.call(idir)
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
	raise "No appropriate default COM port found! Plug in an Arduino unit, or choose manually." if(!found)
	return '\\\\.\\' + found
end

def selectComPort
	if(@ARDUINO_COM_PORT == :default)
		return findDefaultComPort
	else
		return "COM#{@ARDUINO_COM_PORT}"
	end
end

def runAvrdude(work)
	sh "\"#{@ARDUINO_TOOLS_DIR}avr/bin/avrdude\" \"-C#{@ARDUINO_TOOLS_DIR}avr/etc/avrdude.conf\""+
		" -V -patmega328p -carduino -P#{selectComPort} -b115200 -D \"-Uflash:w:#{work.hexFile}:i\""
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
		if(@ARDUINO_ARCHITECTURE == :avr)
			return ' -fno-exceptions -ffunction-sections -fdata-sections'+
				' -mmcu=atmega328p -DF_CPU=16000000L -MMD -DUSB_VID=null -DUSB_PID=null -DARDUINO=105 -DARDUINO_ARCH_AVR'
		elsif(@ARDUINO_ARCHITECTURE == :sam)
			return ' -ffunction-sections -fdata-sections -nostdlib --param max-inline-insns-single=500 -fno-exceptions'+
				' -Dprintf=iprintf -mcpu=cortex-m3 -DF_CPU=84000000L -DARDUINO=157 -DARDUINO_SAM_DUE -DARDUINO_ARCH_SAM -D__SAM3X8E__ -mthumb'+
				' -DUSB_VID=0x2341 -DUSB_PID=0x003e -DUSBCON -DUSB_MANUFACTURER="Unknown" -DUSB_PRODUCT="Arduino Due"'
		else
			raise 'Unhandled architecture: '+@ARDUINO_ARCHITECTURE
		end
	end
	def moduleTargetCFlags
		' -Wno-c++-compat'
	end
	def moduleTargetCppFlags
		' -fno-rtti'
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
			NAME+'.ino.cpp' => idirFlags(idirs),
		}

		@SOURCES = idirs + utils
		@EXTRA_INCLUDES = arduinoBasicIncludeDirs + idirs

		@EXTRA_LINKFLAGS = ' -Os -Wl,--gc-sections -mmcu=atmega328p'
		end
		# Once this object is properly constructed, we can create the ones that depend on it.
		elf = self
		ShellTask.new(@BUILDDIR+NAME+'.eep', [elf],
			"\"#{objCopyName}\" -O ihex -j .eeprom --set-section-flags=.eeprom=alloc,load"+
			" --no-change-warnings --change-section-lma .eeprom=0 \"#{elf}\" \"#{@BUILDDIR+NAME+'.eep'}\"")
		@hexFile = ShellTask.new(@BUILDDIR+NAME+'.hex', [elf],
			"\"#{objCopyName}\" -O ihex -R .eeprom \"#{elf}\" \"#{@BUILDDIR+NAME+'.hex'}\"")
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