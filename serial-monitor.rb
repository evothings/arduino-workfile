# stand-alone ruby program.
# reads from a serial port with specified baud rate, writes to stdout.

require 'rubyserial'

PORTNAME = ARGV[0]
BAUDRATE = ARGV[1].to_i

if(!PORTNAME || !BAUDRATE)
	puts "usage: ruby serial-monitor.rb <portname> <baudrate>"
	exit!(1)
end

# Set up signal handling, so we can quit when properly poked.
Signal.list.each do |name, number|
	Signal.trap(name) do
		puts "SIG#{name}"
		exit!(0)
	end
end

port = Serial.new(PORTNAME, BAUDRATE)
loop do
	#string = port.read(1024)
	#if(string.length > 0)
		#$stdout.write(string)
	#end
	byte = port.getbyte()
	if(byte)
		$stdout.putc(byte)
	else
		$stdout.flush
	end
end
