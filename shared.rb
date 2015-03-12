# This will probably fail on non-Windows platforms.
# TODO: fix.
if(RUBY_PLATFORM =~ /win32/)
require 'win32/registry'

# call block(name, value)
def comPortPotentials(&block)
	Win32::Registry::HKEY_LOCAL_MACHINE.open('HARDWARE\DEVICEMAP\SERIALCOMM') do |reg|
		reg.each do |name, type, value|
			block.call(name, '\\\\.\\' + value)
		end
	end
end
def comPortPrefixes
	['\Device\USBSER', '\Device\VCP']
end

else	# linux
def comPortPotentials(&block)
	Dir.glob('/dev/tty*') do |name|
		block.call(name, name)
	end
end
def comPortPrefixes
	['/dev/ttyUSB', '/dev/ttyACM']
end
end	# win32


def findDefaultComPort
	found = nil
	# This will definitely fail on non-Windows platforms.
	# TODO: fix.

	names = [
		'\Device\USBSER',
		'\Device\VCP',
		'\Device\thcdcacm0',
	]

	# This function is heuristic and may need modification in the future.
	# Investigation has shows that Windows stores the numbers of all active serial ports in this Registry key.
	# Arduino boards are usually connected by USB and appear to have a name starting with '\Device\USBSER'.
	# It is, as yet, unknown how far this will hold true.
	comPortPotentials do |name, value|
		good = false
		comPortPrefixes.each do |prefix|
			good = true if(name.start_with?(prefix))
		end
		if(good)
			raise "Multiple default COM ports found! Unplug all but one, or choose manually." if(found)
			found = value
		end
	end
	if(!found)
		comPortPotentials do |name, value|
			puts value+": "+name
		end
		raise "No appropriate default COM port found! Plug in an Arduino unit, or choose manually."
	end
	return found
end
