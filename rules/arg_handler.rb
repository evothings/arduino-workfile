# Make sure to use this file before base.rb,
# or it will be too late to call Targets.registerArgHandler().

class Works
private
	@@handlers = {}
	@@args_handled = false
	@@args_default = {}
public
	def self.registerArgHandler(a, &block)
		raise "#{a} must be a Symbol" if(!a.is_a?(Symbol))
		raise "Need a block!" if(!block)
		raise "Args already handled!" if(@@args_handled)
		a = a.to_s
		if(@@handlers[a])
			raise "Arg #{a} already has a handler!"
		else
			@@handlers[a] = block
		end
	end
	def self.registerConstArg(sym, default)
		registerArgHandler(sym) do |value|
			#puts "#{sym} = #{value}"
			set_const(sym, value)
		end
		@@args_default[sym] = default
	end
end
