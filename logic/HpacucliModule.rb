#!usr/bin/ruby
#
#Module to check for failed drives on hpacucli servers and partition them if necessary.
#It inherits from the Module superclass.

require "DatamineFstabHandler"
require "set"

class HpacucliModule < Module

    def initialize
        @failedPhysicalDrives = Array.new
	@failedLogicalDrives = Array.new
	@failedHpFormatDriveNames = Array.new
	@failedHpDriveAndStatus = Hash.new
	@unmountedDrives = Array.new
        @displayOutput = Array.new
        @failedDriveLabels = Array.new
    end

#get a lits of failed drives, cleans the list up a little, gets the drive number, the hp drive number format, and the status message for the drive. Also calls checkFailedLogicalDrives
    def checkFailedDrives
=begin
	#----------------------------------------TEST
	#test failed hpacucli failed output file
	File.open("/home/slimvipuwat/SivAutoDisk2/logic/testFailedHpacucli").each do |line|
	    @failedPhysicalDrives.push(line)
	end
	#-------------------------------------------TEST
=end
	@failedPhysicalDrives = `sudo hpacucli ctrl slot=0 pd all show status`
	@cleanFailedPhysicalDrives = Array.new
	@failedPhysicalDrives.each do |e|
        @cleanFailedPhysicalDrives.push(e.chomp)
        end
	@cleanFailedPhysicalDrives.reject! {|e| e.empty?}
        #clean failedPhysicalDrives array
        @failedPhysicalDrives = Array.new
	#get the failed drive number and status message and store in @failedHpDriveAndStatus
	#get hp failed drive number format and store in @failedHpDriveNames
	#get failed drive numbers and store it in @failedPhysicalDrives array
	@cleanFailedPhysicalDrives.each do |d|
	    if d =~ /\w+ (\S+) \(port 1I:box 1:bay (\d+), \S* GB\): (\w+)/
                      
		if $3 == "Failed" || $3 == "Predictive"
		   @failedHpDriveAndStatus[:"#{$2}"] = $3
		   @failedHpFormatDriveNames.push($1)
		   @failedPhysicalDrives.push($2)
	           @failedDriveLabels.push("/hadoop" + $2)
		end
	    end
        end
       #checks logical drives
       self.checkFailedLogicalDrives
    end

#get list of failed logical drives
    def checkFailedLogicalDrives

       @failedLogicalDrives = `sudo hpacucli ctrl slot=0 ld all show status`
       #remove the extra empty lines/spaces
       @cleanFailedLogicalDrives = Array.new
       @failedLogicalDrives.each do |e|
          @cleanFailedLogicalDrives.push(e.chomp)
       end
       @cleanFailedLogicalDrives.reject! {|e| e.empty?}

       #clear FailedLogicalDrives array
       @failedLogicalDrives = Array.new

       #get the failed logical drive numbers
       @cleanFailedLogicalDrives.each do |l|
           if l =~ /\w+ (\d) \(\S+ \S+ \S+ \S+ (\S+)/
	       if $2 == "Failed"
               @failedLogicalDrives.push($1)
	       end	
           end
       end
    end
	
    #display failed drive for use with menu
    def displayFailedDrives
	self.checkFailedDrives
	if @failedHpDriveAndStatus.length > 0 then
           @failedHpDriveAndStatus.each do |drive, status|
	      @displayOutput.push("Physical Drive: #{drive} Status: #{status}")
	   end
	
	   @failedLogicalDrives.each do |l|
	      @displayOutput.push("Logical Drive: #{l} Status: Failed")
	   end
           return @displayOutput
	else
	   #exit if no failed drives found 
	   abort("No failed drives found.")
        end
    end

    #getFailedPhysicalDrives for use with other classes
    def getFailedPhysicalDrives
       self.checkFailedDrives
       return @failedPhysicalDrives
    end

    #getFailedLogicalDrives for use with other classes
    def getFailedLogicalDrives
       self.checkFailedLogicalDrives
       return @failedLogicalDrives
    end

    #turn on LED for failed drives if possible
    def turnOnFailedDrivesLED
       puts "Turning on LED for failed drives..."
       @failedHpFormatDriveNames.each do |l|
          `sudo hpacucli ctrl slot=0 pd #{l.chomp} modify led=on`
       end	   
    end

    #turn off LED for failed drives
    def turnOffFailedDrivesLED
       self.checkFailedDrives
       @failedHpFormatDriveNames.each do |l|
          `sudo hpacucli ctrl slot=0 pd #{l.chomp} modify led=off`
       end
    end

    #start driveReplacementProcess
    def driveReplacementProcess
	#check datamine services
	#self.checkServices

      	self.checkFailedDrives
	#unmounting failed drives
        self.umountFailedDrives	
        #turn on LED for failed drives
        self.turnOnFailedDrivesLED
	#waiting for drive replacement confirmation
        self.waitDriveReplace
        #confirm all physical drives are ok
        self.confirmPhysicalDrive
	#reenabling failed logical drives
      	self.confirmLogicalDrive
	#partition failed drives
      	self.failedDrivePartition
	#instantiate fstabhandler
      	dmFstabHandler = DatamineFstabHandler.new
	#check if failed drives uses uuid
      	diskUsingUuid = dmFstabHandler.checkIfDiskUseUUID(@drivesReplaced)
	#replace uuid if there are drives that use uuid
      	dmFstabHandler.replaceUuid(diskUsingUuid, @fsLetters)
        #mount the new disks
        self.mountFixedDrives
    end

    #unmount failed drives
    def umountFailedDrives
       puts "Unmounting failed drives..."
       dfhlOutput = `df -hl | sort`
       dfhlOutput.each do |f|
          @failedDriveLabels.each do |l|
	      if f =~ /\/\S+\s+\S+\s+\S+\s+\S+\s+\S+ #{l}/ then
		 puts "Unmounted #{l}"
		 `sudo umount #{l}`
	      end
          end
       end
    end

   #mount fixed drives relies on @fsLetters in failedDrivePartition method
   def mountFixedDrives
      @drivesReplaced.each do |d|
	 puts "Mounting disk #{d}."
	 `sudo mount /dev/#{@fsLetters.index(d)}1 /hadoop#{d}`
      end
   end


    #waiting for drives to be replaced
    def waitDriveReplace
       puts "Please replace: "
       @failedPhysicalDrives.each {|d| puts "Drive: " + d}
       #array to store the number for the drives replaced
       @drivesReplaced = Set.new
       #true/false to exit loop
       @doneInputtingDrives = false
       while @doneInputtingDrives == false do
          print "Once the drive(s) have been replaced, please enter the drive number of the replaced drive(e.g if you replaced drive 3 then enter 3) [enter x to exit when you're done inputting drive numbers]: "
          @input = gets.chomp
	  #check if number is between 2-12 if so put into @drivesReplaced array
	  if @input.to_i > 12 || @input.to_i < 2 && @input != "x" then
	     puts "Please enter a number between 2-12"
	  elsif @input.to_i < 12 || @input.to_i > 0
	     @drivesReplaced.add(@input.to_i)
 	  end

          #exit loop
	  if @input == "x" then
	     @doneInputtingDrives = true
	     @drivesReplaced.delete(0)
	  end
       end
     end


     #makes sure all physical drives are "OK"
     def confirmPhysicalDrive
	puts "Confirming all physical drives are OK..."
	physicalDrivesList = Array.new
        physicalDrivesList = `sudo hpacucli ctrl slot=0 pd all show status`	
	cleanPhysicalDrivesList = Array.new
	physicalDiskStatuses = Array.new
        #puts a clean list in cleanPhysicalDrivesList without \n
	physicalDrivesList.each do |d|
 	   cleanPhysicalDrivesList.push(d.chomp)
	end
	#remove empty strings in cleanPhysicalDrivesList
	cleanPhysicalDrivesList.reject! {|e| e.empty?}
	#adds any failed or predictivefailure disks in the @physicalDiskStatuses array
        cleanPhysicalDrivesList.each do |c|
	   if c =~ /\w+ (\S+) \(port 1I:box 1:bay (\d), \S* GB\): (\w+)/ then
	      if $3 == "Failed" || $3 == "Predictive Failure" then
		 physicalDiskStatuses.add("Drive #{$2} status not OK")
	      end
	   end
	end
	#if @physicalDiskStatuses is empty then all physical disks are ok
	if physicalDiskStatuses.empty?  then
	    puts "All physical drive statuses are OK!"
	else
	#if not, abort program
	    puts physicalDiskStatuses
            abort("Not all drive statuses are OK, aborting... please rerun script as needed.")

	end
     end

     #confirmLD are OK and reenable if not
     def confirmLogicalDrive
	logicalDrivesList = Array.new
	logicalDrivesList = `sudo hpacucli ctrl slot=0 ld all show status`
	cleanLogicalDrivesList = Array.new
	#puts a clean list in cleanLogicalDrivesList without \n
	logicalDrivesList.each do |l|
	   cleanLogicalDrivesList.push(l.chomp)
	end
	#remove empty strings in cleanLogicalDrivesList
	cleanLogicalDrivesList.reject! {|e| e.empty?}
        puts "Re-enabling any failed logical drives..."
	#reenable failed LDs
	cleanLogicalDrivesList.each do |l|
	   if l =~ /\w+ (\d+) \(\S+ \S+ \S+ \S+ (\S+)/ && $2 == "Failed"
	      `sudo hpacucli ctrl slot=0 ld #{$1} modify reenable forced` 
	      puts "Logical drive: #{$1} re-enabled."
	   end 
	end
	
       #recreating LD status list
       logicalDrivesList = Array.new
       logicalDrivesList = `sudo hpacucli ctrl slot=0 ld all show status`
       cleanLogicalDrivesList = Array.new
       logicalDrivesList.each do |l|
           cleanLogicalDrivesList.push(l.chomp)
       end
       cleanLogicalDrivesList.reject! {|e| e.empty?}


	#confirm all logical drive OK
	puts "Confirming all logical drives are OK..."
	logicalDrivesOk = true
	cleanLogicalDrivesList.each do |c|
	   if c =~ /\w+ (\d+) \(\S+ \S+ \S+ \S+ (\S+)/ && $2 == "Failed"
	      logicalDrivesOk = false
	   end
	end
	
	if logicalDrivesOk == true then
	   puts "All logical drives OK!"
	else
	   abort("Not all logical drives could be enabled... aborting.")
	end
     end

     #partition failed drives based on @drivesReplaced
     def failedDrivePartition
	#creating hash for filesystem letters
	@fsLetters = Hash.new
	@fsLetters = {"sda" => 1, "sdb" => 2, "sdc" => 3, "sdd" => 4, "sde" => 5, "sdf" => 6, "sdg" => 7, "sdh" => 8, "sdi" => 9, "sdj" => 10, "sdk" => 11, "sdl" => 12}
	#parition failed drives

	@drivesReplaced.each do |p|
	   puts "Paritioning drive #{p}..."
	   `sudo parted /dev/#{@fsLetters.index(p)} --s -- mklabel gpt`
	   `sudo parted /dev/#{@fsLetters.index(p)} --s -- mkpart primary 2048s 100%`
	   `sudo mkfs.ext4 /dev/#{@fsLetters.index(p)}1 -m 0 -L /hadoop#{p}` 
	end

     end



     #check if datamine services are on (fix later)
     def checkServices
	puts "Checking datamine services..."
	#check datanode status
	datanodeStatus = `sudo service datanode status`
	datanodeStatus.chomp
	#ask to continue if service is started else abort
	if datanodeStatus =~ /(\S+) \S+ \S+ \S+ \S+ STARTED/
	   puts "#{$1} service status is running, do you want to continue? y/n"
	   input = gets
	   input.chomp.downcase
	   puts input
	   if input.eqls? "y" then
	   abort("Aborting...")
	   end
	end

	#check tasktracker status
	tasktrackerStatus = `sudo service tasktracker status`
	tasktrackerStatus.chomp
	#ask to continue if service is started else abort
	if tasktrackerStatus =~ /(\S+) \S+ \S+ \S+ \S+ STARTED/ then
	   puts "#{$1} service status is running, do you want to continue? y/n"
	   input = gets
	   input.chomp.downcase
	   if input != "y" then
	   abort("Aborting...")
	   end
	
	end
     end

     
end
#test = HpacucliModule.new
#test.driveReplacementProcess
