
--CONSTANTS========================================
local co = assert(io.open("currentcoordinates.txt", "w"))
scandirectory = "scanresults/"

--RARE CONSTANTS===================================
local commanddirectory = "commandfiles/"
local filetype = ".txt"

local minecommandfilebase = "minecmd"
local PORT = 50001
--END CONSTANTS====================================

local component = require("component")
local event = require("event")
local senddata = require("SendFile")

print("Number of Command files: ")
val = tonumber(io.read())
component.modem.open(PORT)
component.modem.broadcast(PORT, val)
--wait for ack
print("Waiting for command acknowledgment\nPress Ctrl-Alt-C to cancel\n")
_, _, robotaddress, _, _, ack = event.pull("modem_message")
--wait for robot to start sending data
print("Acknowledgement Received")

allfiles = {}
allfilecount = 1 --this must start at one so sendfilesfromtable works, not sure why
for a=0,val-1 do
	allfiles[allfilecount] = commanddirectory .. minecommandfilebase .. a .. filetype
	allfilecount = allfilecount + 1
end
senddata.sendfilesfromtable(robotaddress, allfiles)

print("Commands Sent\nPROGRAM COMPLETE!")
