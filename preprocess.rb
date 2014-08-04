=begin
	Ported to Ruby for use in arduino-workfile.
	Copyright (c) 2014 Evothings AB.

	PdePreprocessor - wrapper for default ANTLR-generated parser
	Part of the Wiring project - http://wiring.org.co

	Copyright (c) 2004-05 Hernando Barragan

	Processing version Copyright (c) 2004-05 Ben Fry and Casey Reas
	Copyright (c) 2001-04 Massachusetts Institute of Technology

	ANTLR-generated parser and several supporting classes written
	by Dan Mosedale via funding from the Interaction Institute IVREA.

	This program is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 2 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program; if not, write to the Free Software Foundation,
	Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
=end

# Returns preprocessed version of the input ino file.
def preprocess(program, inoFileName)
	out = StringIO.new
	out.puts("#line 1 \"#{File.expand_path inoFileName}\"")

	prototypeInsertionPoint = firstStatement(program);
	out.write(program.slice(0, prototypeInsertionPoint));
	out.puts("#include \"Arduino.h\"");

	# print user defined prototypes
	prototypes(program).each do |prototype|
		out.puts(prototype);
	end
	lines = program.slice(0, prototypeInsertionPoint).split("\n", -1);
	out.puts("#line #{(lines.length - 1)}");
	out.write(program.slice(prototypeInsertionPoint .. -1));
	return out.string
end


# Returns the index of the first character that's not whitespace, a comment
# or a pre-processor directive.
def firstStatement(program)
	# whitespace
	p = "\\s+";

	# multi-line and single-line comment
	p += "|(/\\*[^*]*(?:\\*(?!/)[^*]*)*\\*/)|(//.*?$)";

	# pre-processor directive
	p += "|(#(?:\\\\\\n|.)*)";
	pattern = Regexp.new(p);

	index = 0;
	matches = program.scan(pattern) do |match|
		#p match
		#p $~
		return index if($~.begin(0) != index)
		index = $~.end(0);
	end
	#matches = program.scan(pattern);
	#for i in (0..matches.length-1) do
	#	break if(matches.begin(i) != index)
	#	index = matches.end(i);
	#end

	return index;
end


# Strips comments, pre-processor directives, single- and double-quoted
# strings from a string.
# @param in the String to strip
# @return the stripped String
def strip(program)
	# XXX: doesn't properly handle special single-quoted characters
	# single-quoted character
	p = "('.')";

	# double-quoted string
	p += "|(\"(?:[^\"\\\\]|\\\\.)*\")";

	# single and multi-line comment
	p += "|(//.*?$)|(/\\*[^*]*(?:\\*(?!/)[^*]*)*\\*/)";

	# pre-processor directive
	p += "|" + "(^\\s*#.*?$)";

	pattern = Regexp.new(p);
	#Matcher matcher = pattern.match(program);
	#return matcher.replaceAll(" ");
	return program.gsub(pattern, ' ')
end


# Removes the contents of all top-level curly brace pairs {}.
# @param in the String to collapse
# @return the collapsed String
def collapseBraces(program)
	buffer = StringIO.new
	nesting = 0;
	start = 0;

	# XXX: need to keep newlines inside braces so we can determine the line
	# number of a prototype
	for i in (0 .. program.length()-1) do
		if (program[i, 1] == '{')
			if (nesting == 0)
				buffer.write(program.slice(start, i + 1));  # include the '{'
			end
			nesting += 1;
		end
		if (program[i, 1] == '}')
			nesting -= 1;
			if (nesting == 0)
				start = i; # include the '}'
			end
		end
	end

	buffer.write(program.slice(start));

	return buffer.string;
end

# Returns an array of strings; the prototypes for all functions that are defined but not declared.
def prototypes(program)
	program = collapseBraces(strip(program));

	# XXX: doesn't handle ... varargs
	# XXX: doesn't handle function pointers
	prototypePattern = Regexp.new("[\\w\\[\\]\\*]+\\s+[&\\[\\]\\*\\w\\s]+\\([&,\\[\\]\\*\\w\\s]*\\)(?=\\s*;)");
	functionPattern  = Regexp.new("[\\w\\[\\]\\*]+\\s+[&\\[\\]\\*\\w\\s]+\\([&,\\[\\]\\*\\w\\s]*\\)(?=\\s*\\{)");

	# Find already declared prototypes
	prototypeMatches = []
	program.scan(prototypePattern) do |match|
		prototypeMatches << (match + ";")
	end

	# Find all functions and generate prototypes for them
	functionMatches = []
	program.scan(functionPattern) do |match|
		functionMatches << (match + ";")
	end

	# Remove generated prototypes that exactly match ones found in the source file
	functionMatches.reject! { |item| prototypeMatches.include?(item) }

	return functionMatches.uniq;
end
