#!usr/bin/ruby
#
#This class checks if the server is using UUID in fstab and edits fstab if necessary.
#
#

class DatamineFstabHandler
   def initialize
   #creating failed disks using UUID array
   @listOfFailedDisksUsingUUID = Array.new 
   end


     




   #check if fstab is using UUID for failed disks, returns the list of the disks that uses UUID
   def checkIfDiskUseUUID(failedDisks)
      puts "Checking if replaced disks uses UUID in /etc/fstab..."
      File.open("/etc/fstab").each do |line|
         failedDisks.each do |diskNumber|
             if line =~ /\S+ (\/hadoop#{diskNumber})/ then
	        #check if matched disks uses UUID
	        if line =~ /(\w+)=/ then
		   if $1 == "UUID" then
		      puts "Disk #{diskNumber} uses UUID in fstab."
		      @listOfFailedDisksUsingUUID.push(diskNumber)
		   elsif $1 == "LABEL" then
		      puts "Disk #{diskNumber} does not use UUID in fstab."
		   else
		      abort("Cannot detect if replaced disks are using UUID or not. Aborting...")
		   end
		end	
             end
         end
      end
      return @listOfFailedDisksUsingUUID
   end 

   #collect new uuid for diskUsingUuid and put in diskUuid hash containing (diskNumber=newuuid), takes an array of the failed disk using UUID and the hash of the disk name and number on the server
   def replaceUuid(diskUsingUuid, diskHash)
   if @listOfFailedDisksUsingUUID.length > 0 then
      #create hash to store disk UUID
      diskUuid = Hash.new
      #stores the disk number and the UUID belonging to that disk in diskUuid hash
      blkidOutput = `sudo blkid | sort`
      blkidOutput.each do |line|
	 if line =~ /\/dev\/(\w+)1: \S+ UUID="(\S+)"/ then
	    diskUsingUuid.each do |disk|
	       #disk the disk name matches with the name in the blkid then add disk number and uuid to diskUuid
	       if diskHash.index(disk) == $1
		  diskUuid[disk] = $2
	       end
	    end
	 end 
      end
      
      #start creating new updated fstab file here

      #open new and old file
      oldFstab = File.open("/etc/fstab", "r")
      newFstab = File.new("/etc/fstabNewCopy","w+")
      #line added logic to not place duplicate line if a blkid match has occured
      lineAdded = false
      #check each line of old file
      oldFstab.each do |line|
	 #if line has hadoop label check it against diskUuid list
         if line =~ /\S+ \/[a-z]+(\d)/ then
	    diskUuid.each do |k,v|
		#if diskUuid disk number matches with the hadoop label number add the new uuid and set lineAdded true
	        if "#{$1}" == "#{k}" then
                    newFstab.puts("UUID=#{v} /hadoop#{k}                ext4    rw,noatime      1 2")
		    lineAdded = true
                end
            end
	 end
	 #if line was not already added then put the line in the new file
	 if lineAdded == false then
	     newFstab.puts(line)
	 end
         #reset lineAdded varible to false
         lineAdded = false
      end

      #make a backup of original copy and move the new copy to update /etc/fstab
      `sudo cp /etc/fstab /etc/fstabBackUp`
      `sudo mv /etc/fstabNewCopy /etc/fstab`
   end
   end


   

end


#test = DatamineFstabHandler.new
#test.umountFailedDrives
