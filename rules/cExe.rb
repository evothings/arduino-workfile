require "#{File.dirname(__FILE__)}/cCompile.rb"
require "#{File.dirname(__FILE__)}/host.rb"

class ExeWork < CCompileWork
	def initialize(*a)
		super
		Works.setDefaultTarget(:run) do
			sh self.to_s
		end
	end
	def cFlags
		return @cFlags if(@cFlags)
		return @cFlags = linkCmd + "\n" + objectFlags
	end
	def targetName()
		return CCompileTask.genFilename(@COMMON_EXE ? @COMMON_BUILDDIR : @BUILDDIR, @NAME, HOST_EXE_FILE_ENDING)
	end
end
