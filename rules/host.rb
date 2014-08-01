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

# This file defines a few constants that describe the host environment.
# HOST, Symbol. Either :linux, :darwin or :win32.
# HOST_DLL_FILE_ENDING, String. The file ending of DLL files.
# HOST_EXE_FILE_ENDING, String. The file ending of executable files.

# On Linux only:
# HOST_HAS_SDL_SOUND, boolean. True if SDL_Sound is available.
# HOST_HAS_BLUETOOTH, boolean. True if Bluez is available.


if(RUBY_PLATFORM =~ /linux/)
	HOST = :linux
elsif(RUBY_PLATFORM =~ /win32/)
	HOST = :win32
elsif(RUBY_PLATFORM =~ /mingw32/)
	HOST = :win32
elsif(RUBY_PLATFORM =~ /darwin/)
	HOST = :darwin
else
	raise "Unknown platform: #{RUBY_PLATFORM}"
end

if(HOST == :linux)

	if ( File.exist?( "/etc/moblin-release" ) )
		HOST_PLATFORM = :moblin
	elsif ( File.exist?( "/etc/lsb-release" ) )
		HOST_PLATFORM = :ubuntu
	elsif ( File.exist?( "/etc/SUSE-release" ) )
		HOST_PLATFORM = :suse
	elsif ( File.exist?( "/etc/redhat-release" ) )
		HOST_PLATFORM = :redhat
	elsif ( File.exist?( "/etc/redhat_version" ) )
		HOST_PLATFORM = :redhat
	elsif ( File.exist?( "/etc/fedora-release" ) )
		HOST_PLATFORM = :fedora
	elsif ( File.exist?( "/etc/slackware-release" ) )
		HOST_PLATFORM = :slackware
	elsif ( File.exist?( "/etc/slackware_version" ) )
		HOST_PLATFORM = :slackware
	elsif ( File.exist?( "/etc/debian-release" ) )
		HOST_PLATFORM = :debian
	elsif ( File.exist?( "/etc/debian_version" ) )
		HOST_PLATFORM = :debian
	elsif ( File.exist?( "/etc/mandrake-release" ) )
		HOST_PLATFORM = :mandrake
	elsif ( File.exist?( "/etc/gentoo-release" ) )
		HOST_PLATFORM = :gentoo
	elsif ( File.exist?( "/etc/arch-release" ) )
		HOST_PLATFORM = :arch
	else
		raise 'Unknown Linux platform'
	end

	HOST_HAS_SDL_SOUND = File.exist?( "/usr/include/SDL/SDL_sound.h" )
	HOST_HAS_BLUETOOTH = File.exist?( "/usr/include/bluetooth/bluetooth.h" )
end

#warning("Platform: #{HOST}")

if(HOST == :win32) then
	HOST_DLL_FILE_ENDING = '.dll'
	HOST_EXE_FILE_ENDING = '.exe'
	HOST_FOLDER_SEPARATOR = '\\'
elsif(HOST == :darwin)
	HOST_DLL_FILE_ENDING = '.dylib'
	HOST_EXE_FILE_ENDING = ''
	HOST_FOLDER_SEPARATOR = '/'
else
	HOST_DLL_FILE_ENDING = '.so'
	HOST_EXE_FILE_ENDING = ''
	HOST_FOLDER_SEPARATOR = '/'
end
HOST_LIB_FILE_ENDING = '.a'

# Compares two filenames, taking host-dependent case sensitivity into account.
def filenamesEqual(a, b)
	if(HOST == :win32)
		return a.casecmp(b) == 0
	else
		return a == b
	end
end
