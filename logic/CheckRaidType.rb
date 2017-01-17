#!usr/bin/ruby
#
#
#This script is part of SivAutoDisk2 and checks the raid type of the system.
#
#~Methods~
#getRaidType *Return the raid type name*


class CheckRaidType
    def initialize()
        @@raidTypeArray = Array.new
        @@cleanRaidTypeArray = Array.new
    end


    #method to determine the raid type

    def getRaidType
	#begin exception handling for method
	begin
        #tries hpacucli command and cleans the output of leading/trailing whitelines
        #and empty elements
        @@raidTypeArray = `sudo hpacucli ctrl slot=0 pd all show status`
        @@raidTypeArray.each do |i|
        @@cleanRaidTypeArray.push(i.strip)
        @@cleanRaidTypeArray.delete_if { |x| x.empty? }
        end
        #check if raid type is HP by checking the first element of array
        #(right now it only checks for HP later checks for different raid type will be added in the future)
        if @@cleanRaidTypeArray[0] =~ /physicaldrive 1I:1:1/ then
	   #declare HP raid array match
	   return "hpacucli"
	else
	   return "Raid type not recognized!"
	end
 
        rescue
	    puts "Something went wrong in CheckRaidType.getRaidType\n\n\n"
	    puts exception.backtrace
	    raise
	end
    end


end




#sudo: hpacucli: command not found
#test = CheckRaidType.new
#puts test.getRaidType
