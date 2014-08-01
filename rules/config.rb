# load local_config.rb, if it exists.
lc = "#{File.dirname(__FILE__)}/local_config.rb"
require lc if(File.exists?(lc))

require "#{File.dirname(__FILE__)}/util.rb"

# These are default values. Users should not modify them.
# Instead, users should create local_config.rb and put their settings there.

default_const(:PRINT_FLAG_CHANGES, true)
default_const(:USE_COMPILER_VERSION_IN_BUILDDIR_NAME, true)
default_const(:EXIT_ON_ERROR, true)
default_const(:PRINT_WORKING_DIRECTORY, false)
default_const(:CONFIG_PRINT_FILETASK_BACKTRACE, true)
default_const(:CONFIG_CCOMPILE_DEFAULT, 'release')
default_const(:CONFIG_HAVE_COMMON_BUILDDIR, false)

# After all tasks are completed, make sure that none of them are still needed.
# This takes significant time, so should only be turned on to debug the workfile system.
default_const(:CONFIG_CHECK_TASK_INTEGRITY, false)

module GccCompilerModule; end
default_const(:DefaultCCompilerModule, GccCompilerModule)
