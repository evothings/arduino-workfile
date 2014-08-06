This script compiles an Arduino program in a similar fashion to the Arduino IDE, and can also, optionally, run the program on an Arduino unit connected via USB.

Usage:

```ruby build-arduino-generic.rb <path-to-program> [run]```

Before running the script, you must create a text file "localConfig.rb", containing ARDUINO_SDK_DIR,
ARDUINO_LIB_DIR, and ARDUINO_COM_PORT. An example file "localConfig.rb.example" is available.

This script has been tested only on Windows 7. It should work on other versions of Windows without modification.

The compilation part may work on other platforms, but the run-on-arduino part will not.

There are plans to port this script to GNU/Linux and OSX.

This script uses parts of the "workfile" system created by MoSync.
It is licensed under the terms of the GNU General Public License, version 2.
