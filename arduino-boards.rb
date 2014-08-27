# This file contains functions to parse the Arduino's boards.txt file.

# Returns an object such that you can use any dot-syntax identifier
# from boards.txt to get the corresponding string value.
# Attempting to get a nonexistent value returns nil.
# For example:
#
# boards = parseBoardsTxt(filename)
# boards.uno.name => "Arduino Uno"
# boards.foo => nil

require 'ostruct'

class BoardObject < OpenStruct
	def initialize(value = nil)
		@value = value
		super()
	end
	def setValue(value)
		@value = value
	end
	def to_s
		@value
	end
	@@dumpLevel = 0
	def dump
		l = (" "*@@dumpLevel)
		puts l+@value.inspect if(@value)
		self.each do |k,v|
			puts l+k.to_s
			@@dumpLevel = @@dumpLevel + 1
			v.dump
			@@dumpLevel = @@dumpLevel - 1
		end
	end
	def each(&block)
		@table.each(&block)
	end
end

def parseBoardsTxt(filename)
	boards = BoardObject.new
	IO.foreach(filename) do |line|
		# skip comments
		next if(line.start_with?('#'))

		# and empty lines
		line.strip!
		next if(line.length == 0)

		# detect broken lines
		unless(line.include?('.') && line.include?('='))
			p line
			raise "Broken line"
		end

		# parse line
		id, value = line.split('=')
		if(value.is_a?(Array))
			p line
			raise "Broken line"
		end

		# split id
		id = id.split('.')
		o = boards
		id.each do |segment|
			if(!o.respond_to?(segment))
				o.send(segment+'=', BoardObject.new)
			end
			o = o.send(segment)
		end
		o.setValue(value)
	end
	return boards
end
