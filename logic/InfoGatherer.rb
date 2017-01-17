#!usr/bin/ruby
#
#
#This is part of SivAutoDisk2. This script is for gathering system info. It utilizes CheckRaidType class and the DiskReplacementModManager class for information.


class InfoGatherer
    
    def initialize()
        @@hostname = `hostname`
	@@systemType = `sudo dmidecode -t system | grep -i "product name"`
    end


    def getHostName
        return @@hostname
    end
    
    #the @@systemType string will contain "    Product Name: [systemtype]" this removes the "Product Name: "
    #so we're left with the [systemtype]
    def getSystemType
	@@systemType = @@systemType.strip.chomp.gsub(/Product Name: /,"")	
	return @@systemType
    end
    #retrieves and return the raid type
    def getRaidType
        require "CheckRaidType"
        raidType = CheckRaidType.new
	return raidType.getRaidType
    end

    #retrieves failed drives for display
    def getDisplayFailedDrives
       require "DiskReplacementModManager"
       @failedDrivesDisplay = DiskReplacementModManager.new
       @failedDrivesDisplay.displayModuleFailedDisks
    end

    #retreive failed drive for use with other scrips
    def getFailedDrives
       require "DiskReplacementModManager"
       @failedDrives = DiskReplacementModManager.new
       @failedDrives.getFailedDisks
    end

end

#test = InfoGatherer.new
#puts test.getFailedDrives

