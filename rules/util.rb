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

$stdout.sync = true
$stderr.sync = true

def default(constant, value)
	s = ("if(defined?(@#{constant.to_s}) == nil) then @#{constant.to_s} = #{value.inspect} end")
	eval(s)
end

# Unlike Module.const_set, this sets a global constant.
def set_const(name, value)
	s = "#{name.to_s} = #{value.inspect}"
	eval(s)
end

def default_const(constant, value)
	s = ("if(defined?(#{constant.to_s}) == nil) then #{constant.to_s} = #{value.inspect} end")
	eval(s)
end

def set_class_var(c, sym, val)
	c.send(:class_variable_set, sym, val)
end

def get_class_var(c, sym)
	c.send(:class_variable_get, sym)
end

require "#{File.dirname(__FILE__)}/error.rb"
require "#{File.dirname(__FILE__)}/host.rb"
require 'singleton'

class String
	def ext(newEnd)
		doti = rindex('.')
		slashi = rindex('/')
		if((doti && slashi && slashi > doti) || !doti)
			return self + newEnd
		end
		return self[0, doti] + newEnd
	end

	def getExt
		doti = rindex('.')
		slashi = rindex('/')
		if(doti)
			return nil if(slashi && slashi > doti)
			return self[doti..self.length]
		end
		return nil
	end

	def noExt
		doti = rindex('.')
		return self[0, doti]
	end

	# Returns true if self begins with with.
	def beginsWith(with)
		return false if(self.length < with.length)
		return self[0, with.length] == with
	end

	def endsWith(with)
		return false if(self.length < with.length)
		return self[-with.length, with.length] == with
	end
end

def sh(cmd)
	# Print the command to stdout.
	if(cmd.is_a?(Array))
		p cmd
	else
		puts cmd
	end
	if(HOST == :win32 or HOST == :linux)
		success = system(cmd)
		error "Command failed" unless(success)
	else
		# Open a process.
		#IO::popen(cmd + " 2>&1") do |io|
		IO::popen(cmd) do |io|
			# Pipe the process's output to our stdout.
			while !io.eof?
				line = io.gets
				puts line
			end
			# Check the return code
			exitCode = Process::waitpid2(io.pid)[1].exitstatus
			if(exitCode != 0)
				error "Command failed, code #{exitCode}"
			end
		end
	end
end

class Object
	def need(*args)
		args.each do |var|
			if(instance_variable_get(var) == nil)
				raise "Undefined variable: #{var}"
			end
		end
	end
end

class Hash
	def need(*keys)
		keys.each do |key|
			if(!self[key])
				raise "Undefined key: #{key}"
			end
		end
	end
end

def verbose_rm_rf(list)
	case list
	when Array
		arr = list.collect do |p| p.to_str end
		puts "Remove #{arr.inspect}"
	else
		puts "Remove '#{list}'"
	end
	FileUtils.rm_rf(list)
end

HashMergeAdd = Proc.new {|key, old, new| old + new }


# returns a command-line string with the correct invocation of sed for all platforms
def sed(script)
	if(!self.class.class_variable_defined?(:@@sedIsGnu))
		open("|sed --version 2>&1") do |file|
			@@sedIsGnu = file.gets.beginsWith('GNU sed')
		end
	end
	if((@@sedIsGnu && HOST != :win32) || HOST == :darwin)
		return "sed '#{script}'"
	else
		return "sed #{script}"
	end
end

# EarlyTime is a fake time that occurs _before_ any other time value.
# Its instance is called EARLY.
# Equivalent to a file not existing.
class EarlyTime
	include Comparable
	include Singleton

	def <=>(other)
		return 0 if(other.instance_of?(EarlyTime))
		return -1
	end

	def to_s
		"<EARLY TIME>"
	end
end
EARLY = EarlyTime.instance

# LateTime is a fake time that occurs _after_ any other time value.
# Its instance is called LATE.
class LateTime
	include Comparable
	include Singleton

	def <=>(other)
		return 0 if(other.instance_of?(LateTime))
		return 1
	end

	def to_s
		"<LATE TIME>"
	end
end
LATE = LateTime.instance

class Time
	alias_method(:old_comp, :<=>)
	def <=>(other)
		return 1 if(other.instance_of?(EarlyTime))
		return -1 if(other.instance_of?(LateTime))
		return old_comp(other)
	end
end

# Extension to class File, to make sure that the drive letter is always lowercase.
# This resolves an issue where programs were rebuilt due to file paths being changed,
# itself due to strange behaviour in the Windows command-line console.
class File
	if(HOST == :win32)
		def self.expand_path_fix(p)
			ep = self.expand_path(p)
			return ep if(ep.length <= 3)
			if(ep[1,1] == ':')
				ep[0,1] = ep[0,1].downcase
			end
			return ep
		end
	else
		class << self	# alias class methods, rather than instance methods
			alias_method(:expand_path_fix, :expand_path)
		end
	end
end

def min(a, b)
	return a if(a < b)
	return b
end

def max(a, b)
	return (a > b) ? a : b
end

def aprint(a)
	print "["
	first = true
	a.each do |item|
		if(first) then
			first = false
		else
			print ", "
		end
		print item
	end
	print "]\n"
end

def number_of_processors
  if HOST == :linux
    return `cat /proc/cpuinfo | grep processor | wc -l`.to_i
  elsif HOST == :darwin
    return `sysctl -n hw.logicalcpu`.to_i
  elsif HOST == :win32
    # this works for windows 2000 or greater
    require 'win32ole'
    wmi = WIN32OLE.connect("winmgmts://")
    wmi.ExecQuery("select * from Win32_ComputerSystem").each do |system|
      return system.NumberOfLogicalProcessors
    end
  end
  raise "can't determine 'number_of_processors' for '#{HOST}'"
end

def startWebBrowser(url)
	if(RUBY_PLATFORM =~ /mingw32/)
		system "start #{url}"
	elsif(RUBY_PLATFORM =~ /linux/)
		system "x-www-browser #{url}"
	else
		puts url
		puts "Unsupported platform; start the browser yourself."
	end
end

module Kernel
if(RUBY_VERSION < "1.9")
	def backtrace
		begin
			raise
		rescue => e
			return e.backtrace
		end
	end
end
end
