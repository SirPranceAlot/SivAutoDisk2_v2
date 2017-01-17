#!usr/bin/ruby
#
#importing required classes
require "InfoGatherer"
require "DiskReplacementModManager"


class DriveReplacementMenu
    #display menu method
    def displayMenu
    #initializing objects
    info  = InfoGatherer.new
    puts "~~SivAutoDisk 2~~\n\n"
    puts "This script is for automating disk replacements. "
    puts "Hostname: " + info.getHostName
    puts "Disk(s) status : "  
    puts info.getDisplayFailedDrives


    puts "System type: " + info.getSystemType
    puts "Raid type: " + info.getRaidType
    
    
    puts "Do you want to continue the drive replacement process?"
    print "y/n:"
    input = gets.chomp
       if input.downcase == "y" then
       puts "yes"
       replaceStart = DiskReplacementModManager.new
       replaceStart.startDriveReplacementProcessForModule
       end

    #prompt to remove drive and insert new drives

    end
end

#test = DriveReplacementMenu.new
#test.displayMenu
