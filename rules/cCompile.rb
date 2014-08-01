require "#{File.dirname(__FILE__)}/arg_handler.rb"

Works.registerArgHandler(:CONFIG) do |value|
	CCompileWork.setConfig(value)
end

require "#{File.dirname(__FILE__)}/work.rb"
require "#{File.dirname(__FILE__)}/config.rb"
require "#{File.dirname(__FILE__)}/flags.rb"
require 'fileutils'

if(DefaultCCompilerModule == GccCompilerModule)
	require "#{File.dirname(__FILE__)}/gccModule.rb"
end

# Base class for compiling C/C++/Objective-C files.
# FileTask.name is the name of the object file.
# The source file and any headers it might include are prerequisites.

# This class does not specify the use of any particular compiler, like GCC, LLVM, QCC or MSVC.
# Such information is included from a module whose name is an argument to CppTask.initialize.

# The default compiler is specified in config.rb, which may be locally overridden by local_config.rb.

class CCompileTask < FileTask
	include FlagsChanged

	def initialize(srcTask, flags, builddir, requirements, compilerModule = DefaultCCompilerModule)
		@compilerModule = compilerModule
		extend compilerModule

		@SOURCE = srcTask
		@DEPFILE = CCompileTask.genFilename(builddir, srcTask, '.mf')
		@NAME = CCompileTask.genFilename(builddir, srcTask, objFileEnding)
		@FLAGS = flags

		#p srcTask, requirements

		@requirements = requirements

		@prerequisites = [
			srcTask,
			DirTask.new(builddir),
		]

		# Only if the file is not already needed do we care about extra dependencies.
		setNeeded
		if(!needed)
			@prerequisites += loadDependencies
		end

		super(@NAME)
	end

	def cFlags
		return @cFlags if(@cFlags)
		return @cFlags = compileCmd
	end

	def fileExecute
		execFlags
		sh cFlags
		postCompile
	end

	# Returns a path representing a generated file, given a source filename and a new file ending.
	def self.genFilename(builddir, source, ending)
		builddir + File.basename(source.to_s).ext(ending)
	end
end


# Base class for compiling multiple C-type files into a single unit.
# For example, an exe, dll or lib file.

# Subclasses MUST implement the following methods:
# targetName() -> String	# Returns name of target file.

# Instances MUST set one or more of the following variables:
# @SOURCES, @SOURCE_FILES, @SOURCE_TASKS or @EXTRA_OBJECTS.

# Instances MUST set ALL the following variables:
# @NAME
## String, base name of the target.
## Example: in an ExeWork, if @NAME == 'foo', target becomes @BUILDDIR/foo.exe.

# Instances MAY provide the other variables found in set_defaults.

class CCompileWork < FileTask
	include FlagsChanged

	def self.setConfig(value)
		@@CONFIG = value
	end

	# Called before the block passed to initialize().
	def earlyDefaults
		# String. 'release' or 'debug'.
		@CONFIG = @@CONFIG if(defined?(@@CONFIG))
		default(:CONFIG, CONFIG_CCOMPILE_DEFAULT)
	end

	# Called after the block passed to initialize().
	def set_defaults
		# Array of Strings, directories that will be searched for source files.
		default(:SOURCES, [])
		# Array of Strings, paths to files that should be compiled, even though they are outside the SOURCES.
		default(:SOURCE_FILES, [])
		# Array of FileTasks, generated source files that should be compiled along with the others.
		default(:SOURCE_TASKS, [])

		# Array of Strings, names of files that should not be compiled.
		# Applies only to files found by @SOURCES.
		default(:IGNORED_FILES, [])
		# Array of FileTasks, precompiled object files, to link with.
		default(:EXTRA_OBJECTS, [])

		# String, extra flags used when compiling C files.
		default(:EXTRA_CFLAGS, '')
		# String, extra flags used when compiling C++ files.
		default(:EXTRA_CPPFLAGS, '')
		# Array of Strings, extra include directories.
		default(:EXTRA_INCLUDES, [])
		# String, extra flags passed to the linker.
		default(:EXTRA_LINKFLAGS, '')

		# Array of FileTasks, static libraries to link with.
		default(:LOCAL_LIBS, nil)
		# Array of FileTasks, shared libraries to link with.
		default(:LOCAL_DLLS, nil)
		# Array of Strings, names of libraries to link with.
		default(:LIBRARIES, [])

		# Hash(String,String). Key is the filename of a source file.
		# Value is extra compile flags to be used when compiling that file.
		default(:SPECIFIC_CFLAGS, {})

		# Boolean. While true, assembly source files will be automatically collected
		# from SOURCE directories, much like C/C++ files.
		default(:COLLECT_S_FILES, true)

		# String, name of the base build directory.
		default(:BUILDDIR_BASE, File.expand_path_fix('build') + '/')
		# String, added to the beginning of build sub-directories.
		default(:BUILDDIR_PREFIX, '')
		# String, name of the build sub-directory.
		default(:BUILDDIR_NAME, @BUILDDIR_PREFIX + @CONFIG + builddir_postfix)
		# String, path of the build directory.
		default(:BUILDDIR, @BUILDDIR_BASE + @BUILDDIR_NAME + '/')

		if(CONFIG_HAVE_COMMON_BUILDDIR)
			# String, path where LOCAL_LIBS and LOCAL_DLLS are stored.
			default(:COMMON_BUILDDIR, File.expand_path_fix("#{File.dirname(__FILE__)}/../build") + '/' + @BUILDDIR_NAME + '/')
			# Boolean, used by ExeWork. If true, the ExeWork's TARGETDIR is COMMON_BUILDDIR.
			default(:COMMON_EXE, false)
			# String, path of the directory where libs and dlls are created.
			default(:LIB_TARGETDIR, @COMMON_BUILDDIR)
		else
			default(:LIB_TARGETDIR, @BUILDDIR)
		end

		# Array of Tasks, requirements for all CCompileTasks generated by this Work
		default(:REQUIREMENTS, [])

		# String, path to a directory. If set, the Work's target will be copied there.
		default(:INSTALLDIR, nil)

		default(:prerequisites, [])
	end

	def checkSources
		return if(@sourcesChecked)
		@sourcesChecked = true
		# Make source file variables are valid.
		sources = [:@SOURCES, :@SOURCE_FILES, :@SOURCE_TASKS, :@EXTRA_OBJECTS]
		haveSource = false
		sources.each do |sn|
			s = instance_variable_get(sn)
			raise "#{sn} may not be empty." if(s && s.empty?)
			haveSource = true if(s)
		end
		if(!haveSource)
			err = "Need #{sources[0..-1].join(', ')} or #{sources.last}."
			raise err
		end
	end

	def initialize(compilerModule = DefaultCCompilerModule, &block)
		@compilerModule = compilerModule
		extend compilerModule
		setCompilerVersion # needed by some blocks

		earlyDefaults

		instance_eval(&block) if(block)

		checkSources

		need(:@NAME)

		set_defaults

		# find source files
		cfiles = collect_source_files('.c')
		@cppfiles = collect_source_files('.cpp') + collect_source_files('.cc') + collect_source_files('.C')

		sfiles = []
		if(@COLLECT_S_FILES)
			sfiles = collect_source_files('.s')
		end

		all_sourcefiles = cfiles + @cppfiles + sfiles

		raise "No source files found!" if(all_sourcefiles.empty?)

		# avoid rebuilds due to random file order
		all_sourcefiles.sort! do |a,b| a.to_s <=> b.to_s; end

		loadCommonFlags

		@object_tasks = collect_objects(all_sourcefiles) + @EXTRA_OBJECTS
		if(CONFIG_HAVE_COMMON_BUILDDIR)
			llo = @LOCAL_LIBS.collect { |ll| FileTask.new(@COMMON_BUILDDIR + ll + ".a") }
			lld = @LOCAL_DLLS.collect { |ld| FileTask.new(@COMMON_BUILDDIR + lldPrefix + ld + HOST_DLL_FILE_ENDING) }
			@object_tasks += llo + lld
			@prerequisites += [DirTask.new(@COMMON_BUILDDIR)]
		else
			raise "@LOCAL_LIBS not allowed because !CONFIG_HAVE_COMMON_BUILDDIR" if(@LOCAL_LIBS)
			raise "@LOCAL_DLLS not allowed because !CONFIG_HAVE_COMMON_BUILDDIR" if(@LOCAL_DLLS)
		end
		@prerequisites += @object_tasks
		@prerequisites << DirTask.new(@LIB_TARGETDIR)

		# Gotta do this before it's safe to use this task as a prerequisite.
		setName(targetName())
		setNeeded

		if(@INSTALLDIR)
			CopyFileTask.new(@INSTALLDIR + '/' + File.basename(@NAME), self, [DirTask.new(@INSTALLDIR)])
		end

		super(@NAME)
	end

	def lldPrefix
		if(@TARGET_PLATFORM == :win32)
			return ''
		else
			return 'lib'
		end
	end

	def fileExecute
		execFlags
		preLink
		sh linkCmd
		postLink
	end

private

	def check_extra_sourcefile(file, ending)
		return false if(file.getExt != ending)
		raise "Extra sourcefile '#{file}' does not exist!" if(!File.exist?(file))
		return true
	end

	# returns an array of source-code FileTasks
	def collect_source_files(ending)
		files = @SOURCES.collect {|dir| Dir[dir+'/*'+ending]}
		files.flatten!
		files.reject! {|file| @IGNORED_FILES.member?(File.basename(file)) ||
			!file.end_with?(ending)}	# this one's for windows, whose Dir[] implementation is not case-sensitive.
		files += @SOURCE_FILES.select do |file| check_extra_sourcefile(file, ending) end
		tasks = files.collect do |file| FileTask.new(file) end
		extra_tasks = @SOURCE_TASKS.select do |file| file.to_s.getExt == ending end
		# todo: make sure all sourcetasks are collected by one of the calls to this function.
		return extra_tasks + tasks
	end

	def getFlags(source)
		need(:@SPECIFIC_CFLAGS)
		ext = source.to_s.getExt
		flags = @CFLAGS_MAP[ext]
		if(flags == nil) then
			error "Bad ext: '#{ext}' on source '#{source}'"
		end
		return flags + @SPECIFIC_CFLAGS.fetch(File.basename(source.to_s), "")
	end

	# returns an array of CCompileTasks
	def collect_objects(sources)
		return sources.collect do |s| CCompileTask.new(s, getFlags(s), @BUILDDIR, @REQUIREMENTS, @compilerModule) end
	end
end
