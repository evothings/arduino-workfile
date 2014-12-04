# This will probably fail on non-Windows platforms.
# TODO: fix.
require 'win32/registry'

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
			if(name.start_with?('\Device\USBSER') || name.start_with?('\Device\VCP'))
				raise "Multiple default COM ports found! Unplug all but one, or choose manually." if(found)
				found = value
			end
		end
	end
	if(!found)
		Win32::Registry::HKEY_LOCAL_MACHINE.open('HARDWARE\DEVICEMAP\SERIALCOMM') do |reg|
			reg.each do |name, type, value|
				puts value+": "+name
			end
		end
		raise "No appropriate default COM port found! Plug in an Arduino unit, or choose manually."
	end
	return '\\\\.\\' + found
end
