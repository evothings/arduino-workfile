require "#{File.dirname(__FILE__)}/cCompile.rb"
require "#{File.dirname(__FILE__)}/host.rb"

class LibWork < CCompileWork
	def cFlags
		return @cFlags if(@cFlags)
		return @cFlags = libCmd + objectFlags
	end
	def fileExecute
		execFlags
		preLib
		sh libCmd
		postLib
	end
	def targetName()
		return CCompileTask.genFilename(@LIB_TARGETDIR, @NAME, HOST_LIB_FILE_ENDING)
	end
end
