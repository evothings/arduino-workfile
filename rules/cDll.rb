require "#{File.dirname(__FILE__)}/cCompile.rb"
require "#{File.dirname(__FILE__)}/host.rb"

class DllWork < CCompileWork
	def cFlags
		return @cFlags if(@cFlags)
		return @cFlags = dllCmd + objectFlags
	end
	def targetName()
		return CCompileTask.genFilename(@LIB_TARGETDIR, @NAME, HOST_DLL_FILE_ENDING)
	end
end
