class Base
	def initialize
		puts "Base"
	end
private
	def foo
		puts "foo"
	end
end

class Sub < Base
	def initialize
		puts "Sub"
		super
	end
	def bar
		Base.new.foo
		puts "bar"
	end
end

Sub.new.bar
