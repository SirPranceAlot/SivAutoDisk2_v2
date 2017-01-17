#!/usr/bin/ruby
#
#SivAutoDisk2 main controller

#Gets the current directory to be added to $LOAD_PATH
#need this in order to import classes from the logic folder
currentDirectory = `pwd`
currentDirectory = currentDirectory.chomp + "/logic"

#Adds the logic directory to $LOAD_PATH
$LOAD_PATH << File.dirname(currentDirectory + "/logic")
#importing classes
#require "DriveReplacementMenu"
require "DriveReplacementMenu"



#initializing object
menu = DriveReplacementMenu.new
#display menu
menu.displayMenu



