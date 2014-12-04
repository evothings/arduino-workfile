# stand-alone ruby program.
# reads from a serial port with specified baud rate, writes to stdout.

require 'rubyserial'
require './shared.rb'

PORTNAME = ARGV[0] || findDefaultComPort
BAUDRATE = (ARGV[1] || 9600).to_i

if(!PORTNAME || !BAUDRATE)
	puts "usage: ruby serial-monitor.rb [portname] [baudrate]"
	exit!(1)
end

# Set up signal handling, so we can quit when properly poked.
Signal.list.each do |name, number|
	Signal.trap(name) do
		puts "SIG#{name}"
		if(name != 'EXIT')
			exit!(0)
		end
	end
end

puts "Using port #{PORTNAME} @ #{BAUDRATE} baud."
port = Serial.new(PORTNAME, BAUDRATE)
loop do
	#string = port.read(1024)
	#if(string.length > 0)
		#$stdout.write(string)
	#end
	byte = port.getbyte()
	if(byte)
		$stdout.putc(byte)
		$stdout.flush
	end
	#line = $stdin.gets()
	#if(line)
	#	p line
	#	port.write(line)
	#end
#	if($stdin.eof?)
#		puts "$stdin ended, quitting..."
#		exit!(0)
#	end
end
