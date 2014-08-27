#!/usr/bin/ruby

# This program builds all Arduino libraries.

# todo: test every architecture and variant.
# make sure every library is compiled at least once.

# todo: build every example.

require File.dirname(File.expand_path __FILE__)+'/arduino-libs-shared.rb'

LibBuilder.new(DefaultArduinoEnvironment).run

DefaultArduinoEnvironment.runArduinoWorks
