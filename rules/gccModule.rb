require "#{File.dirname(__FILE__)}/loader_md.rb"
require "#{File.dirname(__FILE__)}/cCompile.rb"
require "#{File.dirname(__FILE__)}/gccFlags.rb"


def get_gcc_version_info(gcc)
	info = {}
	open("|\"#{gcc}\" -v 2>&1") do |file|
		file.each do |line|
			parts = line.split(/ /)
			#puts "yo: #{parts.inspect}"
			if(parts[0] == 'Target:' && parts[1].strip == 'arm-elf')
				info[:arm] = true
			end
			if(parts[0] == "gcc" && parts[1] == "version")
				info[:ver] = parts[2].strip
			elsif(parts[0] == 'clang' && parts[1] == 'version')
				info[:clang] = true
				info[:ver] = parts[2].strip
			end
		end
	end
	if(!info[:ver])
		open("|\"#{gcc}\" -dumpversion 2>&1") do |file|
			info[:ver] = file.read.strip
			info[:ver] = nil if(info[:ver].length == 0)
		end
		# Shell may sprout garbage. Make sure process exited without error.
		info[:ver] = nil if(!$?.success?)
	end
	if(!info[:ver])
		puts gcc
		error("Could not find gcc version.")
	end
	info[:string] = ''
	info[:string] << 'arm-' if(info[:arm])
	info[:string] << 'clang-' if(info[:clang])
	info[:string] << info[:ver]
	return info
end

module GccCompilerModule
	include GccFlags

	def gcc
		'gcc'
	end

	def objFileEnding
		'.o'
	end

	def builddir_postfix
		if(USE_COMPILER_VERSION_IN_BUILDDIR_NAME)
			return '-' + gccVersionInfo[:string]
		else
			return ''
		end
	end

	def loadDependencies
		if(!File.exists?(@DEPFILE))
			@needed = "Because the dependency file is missing:"
			return []
		end
		# The first file in a GCC-generated MF file is the C/CPP file itself.
		# Gotta skip it, or we'll have a Task type collision.
		MakeDependLoader.load(@DEPFILE, @NAME, 1)
	end

private
	@@gcc_info = {}
	def gccVersionInfo
		if(!@@gcc_info[gcc])
			@@gcc_info[gcc] = get_gcc_version_info(gcc)
		end
		return @@gcc_info[gcc]
	end

public

	def setCompilerVersion
		info = gccVersionInfo

		@GCC_IS_V4 = info[:ver][0] == "4"[0]
		if(@GCC_IS_V4)
			@GCC_V4_SUB = info[:ver][2, 1].to_i
		end

		# Assuming for the moment that clang is command-line-compatible with gcc 4.2.
		@GCC_IS_CLANG = info[:clang]
		if(@GCC_IS_CLANG)
			@GCC_IS_V4 = true
			@GCC_V4_SUB = 2
		end

		@GCC_WNO_UNUSED_BUT_SET_VARIABLE = ''
		@GCC_WNO_POINTER_SIGN = ''
		if(@GCC_IS_V4 && @GCC_V4_SUB >= 6)
			@GCC_WNO_UNUSED_BUT_SET_VARIABLE = ' -Wno-unused-but-set-variable'
			@GCC_WNO_POINTER_SIGN = ' -Wno-pointer-sign'
		end
		default(:TARGET_PLATFORM, HOST)
	end

	# used only by CCompileWork.
	def loadCommonFlags
		setCompilerVersion

		define_cflags

		@CFLAGS_MAP = {
			'.c' => @CFLAGS,
			'.cpp' => @CPPFLAGS,
			'.cc' => @CPPFLAGS,
			'.C' => @CPPFLAGS,
			'.s' => ' -Wa,--gstabs' + @CFLAGS,
			'.S' => ' -Wa,--gstabs' + @CFLAGS,
		}
	end

	def compileCmd
		flags = @FLAGS

		@TEMPDEPFILE = @DEPFILE + 't'
		flags += " -MMD -MF \"#{@TEMPDEPFILE}\""

		if(HOST == :win32)
			raise hell if(@NAME[1,1] != ':')
		end

		return "\"#{gcc}\" -o \"#{@NAME}\"#{flags} -c \"#{@SOURCE}\""
	end

	def postCompile
		if(!File.exist?(@TEMPDEPFILE) && @SOURCE.to_s.getExt.downcase == '.s')
			# Some .s files generate no dependency file when compiled.
			FileUtils.touch(@DEPFILE)
			return
		end
		# In certain rare cases (error during preprocess caused by a header file)
		# gcc may output an empty dependency file, resulting in an empty dependency list for
		# the object file, which means it will not be recompiled, even though it should be.
		# Therefore, we only write the real depFile after successful compilation.
		FileUtils.mv(@TEMPDEPFILE, @DEPFILE)
	end

	private
	def objectFlags
		"\"#{@object_tasks.join("\"\n\"")}\""
	end
	def objectsFileName
		CCompileTask.genFilename(@BUILDDIR, @NAME, '.objects')
	end
	def linkerName
		@cppfiles.empty? ? 'gcc' : 'g++'
	end

	public
	def preLink
		file = open(objectsFileName, 'w')
		file.puts objectFlags
		file.close
	end

	def linkCmd
		flags = "#{@FLAGS}#{@EXTRA_LINKFLAGS}"
		@LIBRARIES.each do |lib|
			flags += " -l#{lib}"
		end
		raise hell if(@LIBRARIES.uniq.length != @LIBRARIES.length)
		raise hell if(@object_tasks.uniq.length != @object_tasks.length)
		return "\"#{linkerName}\" -o \"#{@NAME}\" @#{objectsFileName}#{flags}"
	end

	def dllCmd
		raise hell if(@FLAGS)
		@FLAGS = ' -shared -Wl,--no-undefined'
		return linkCmd
	end

	def postLink
	end

	def preLib
		preLink
		# ar does not remove out-of-date archive members.
		# The file must be deleted if we are to get a clean build.
		FileUtils.rm_f(@NAME)
	end

	def libCmd
		return "ar rcs #{@NAME}#{@FLAGS} @#{objectsFileName}"
	end

	def postLib
	end
end
