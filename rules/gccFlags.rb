# Copyright (C) 2009 Mobile Sorcery AB
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License, version 2, as published by
# the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; see the file COPYING.  If not, write to the Free
# Software Foundation, 59 Temple Place - Suite 330, Boston, MA
# 02111-1307, USA.

require "#{File.dirname(__FILE__)}/util.rb"

#defines @CFLAGS and @CPPFLAGS

module GccFlags
def define_cflags
super if(defined?(super))

# Valid in GCC 4.3 and later.
gcc43_warnings = ' -Wvla -Wlogical-op'

# Valid in both C and C++ in GCC 4.3 and later, but only in C in 4.2 and earlier.
gcc43_c_warnings = ' -Wmissing-declarations'

# Valid in GCC 4.0 and later.
gcc4_warnings = ' -Wvariadic-macros -Wmissing-include-dirs'

# Valid in C only, in GCC 4.5 and later.
gcc_45_c_warnings = ' -Wc++-compat'

# Valid in C++ only, in GCC 4.6 and later.
gcc_46_cpp_warnings = ' -Wnoexcept'

# Valid in GCC 4.7 and later.
gcc47_warnings = '  -Wunused-local-typedefs'

# Valid in C++ only, in GCC 4.7 and later.
gcc47_cpp_warnings = ' -Wdelete-non-virtual-dtor'

lesser_warnings = ' -Wpointer-arith -Wundef -Wfloat-equal -Winit-self'

pedantic_warnings = ' -Wmissing-noreturn -Wmissing-format-attribute'

# Valid in C.
pendantic_c_warnings = ' -Wstrict-prototypes -Wold-style-definition -Wmissing-prototypes'

# Valid in C.
lesser_conly = ' -Wnested-externs -Wdeclaration-after-statement'
# -Wno-format-zero-length"

# Broken in C++, GCC 4.3.3, 4.4.1, 4.2.1 and in 3.4.5 -O2.
optimizer_dependent = " -Wunreachable-code -Winline"
if(@GCC_IS_V4 || (!@GCC_IS_V4 && @CONFIG == ""))
	pendantic_c_warnings += optimizer_dependent
else
	pedantic_warnings += optimizer_dependent
end

standard_warnings = " -Wall -Werror -Wextra -Wno-unused-parameter -Wwrite-strings -Wshadow"


include_dirs = @EXTRA_INCLUDES
include_flags = include_dirs.collect {|dir| " -I\""+File.expand_path_fix(dir)+'"'}.join

c_flags = ' -std=gnu99'

version_warnings = ''
base_flags = ''
cpp_flags = ''
end_flags = ''

if(@PROFILING)
	base_flags << ' -pg'
end

if(@GCC_IS_V4) then
	if(@TARGET_PLATFORM != :win32)
		base_flags << ' -fvisibility=hidden'
	end
	version_warnings << gcc4_warnings
	if(@GCC_V4_SUB >= 3) then
		version_warnings << gcc43_c_warnings + gcc43_warnings
		#cpp_flags << ' -std=gnu++0x'
		#cpp_flags << ' -DHAVE_TR1'
	end
	if(@GCC_V4_SUB >= 5)
		#valid in C only, in GCC 4.5 and later
		c_flags << gcc_45_c_warnings
	end
	if(@GCC_V4_SUB >= 6)
		#valid in C only, in GCC 4.5 and later
		cpp_flags << gcc_46_cpp_warnings
	end
	if(@GCC_V4_SUB >= 7)
		version_warnings << gcc47_warnings
		cpp_flags << gcc47_cpp_warnings
	end
end
if(!(@GCC_IS_V4 && @GCC_V4_SUB >= 3)) then
	lesser_conly << gcc43_c_warnings
end

if(@CONFIG == 'debug') then
	config_flags = ' -g -O0'
elsif(@CONFIG == 'release')
	config_flags = ''
	config_flags << ' -g -Os'
	#config_flags << ' -fomit-frame-pointer' if(@GCC_IS_V4)
else
	error "wrong configuration: #{@CONFIG}"
end

target_cflags = ''
if(@TARGET_PLATFORM == :win32)
	target_flags = ' -DWIN32'
	target_cppflags = ''
elsif(@TARGET_PLATFORM == :arduino)
	target_flags = moduleTargetFlags
	target_cflags = moduleTargetCFlags
	target_cppflags = moduleTargetCppFlags
elsif(@TARGET_PLATFORM == :linux)
	target_flags = ' -DLINUX -fPIC'
	target_cppflags = ''
elsif(@TARGET_PLATFORM == :darwin)
	sdkAdress = '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.7.sdk'
	if(!File.exist?(sdkAdress))
		sdkNumber = (File.exist?('/Developer/SDKs/MacOSX10.5.sdk')) ? '5':'6'
		sdkAdress = "/Developer/SDKs/MacOSX10.#{sdkNumber}.sdk"
	end
	target_flags = " -isysroot #{sdkAdress} -mmacosx-version-min=10.5 -DDARWIN -fPIC"
	target_cppflags = ''
else
	if(respond_to?(:customTargetSetFlags))
		target_flags, target_cppflags = customTargetSetFlags
	else
		error "Unsupported target platform: #{@TARGET_PLATFORM}"
	end
end


flags_base = config_flags + base_flags + include_flags + standard_warnings + lesser_warnings +
	pedantic_warnings + version_warnings

cflags_base = c_flags + flags_base + lesser_conly + pendantic_c_warnings + end_flags

if(@GCC_IS_V4)
	no_rtti = ''
else
	no_rtti = ' -fno-rtti'
end

cppflags_base = cpp_flags + no_rtti + flags_base + end_flags
# -Wno-deprecated

@CFLAGS = cflags_base + target_flags + target_cflags + @EXTRA_CFLAGS
@CPPFLAGS = cppflags_base + target_flags + target_cppflags + @EXTRA_CPPFLAGS
end
end
