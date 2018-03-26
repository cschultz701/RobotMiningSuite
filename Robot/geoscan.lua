--OpenComputers Mining v1.0
--geoscan.lua v3.0
--Scans requested area and generates files based on results

--for use with geoscancontrol.lua v1.0
--requires SendFile.lua v1.0
--requires movemine.lua v1.0

--Scans an area from the center point of a relative position passed by geoscancontrol.
--Files are split into groups such that no file exceeds the constant max file size.
--Generates scanValueX.txt with coordinates from the navigation upgrade with valuable blocks.
--Generates scanAirX.txt with coordinates from the navigation upgrade with air (no blocks).
--Generates scanWaterX.txt with coordinates from the navigation upgrade with water or lava.
--Files are formatted with one line equal to one block, with x, y and z in plain text and 
--tab delimited. Files are placed into a separate scan directory.
--Upon scan completion, transfers all files via network to the control computer that is
--running geoscancontrol.

--CONSTANTS========================================
--determines the relative limits where the robot stops mining
local XMIN = -23
local YMIN = -32
local ZMIN = -23
local XMAX = 23
local YMAX = 32
local ZMAX = 23

--geolyzer always says air = 0
--anything more than 0 is a block
--Stone = 1.5 +/- noise
--Lead = 2 +/- noise
--All other ores tried = 3 +/- noise
--Water/Lava = 100 +/- noise
local VALUEBOUNDARY = 2.3

--determines what the minimum amount of energy is before going back home
local MINIMUMPOWER = 5000
--RARE CONSTANTS===================================

scandirectory = "scanresults/"
lootfiletype = ".txt"

--file to save loot locations to
local lfilebase = "scanValue"
local lcount = 0
local lbytes = 0
local lf = assert(io.open(scandirectory .. lfilebase .. lcount .. lootfiletype, "w"))

--file to save air locations to
local afilebase = "scanAir"
local acount = 0
local abytes = 0
local af = assert(io.open(scandirectory .. afilebase .. acount .. lootfiletype, "w"))

--file to save water/lava locations to
local wfilebase = "scanWater"
local wcount = 0
local wbytes = 0
local wf = assert(io.open(scandirectory .. wfilebase .. wcount .. lootfiletype, "w"))

--file to save map origin point to
local coordfilename = "coordinates"
local cf = assert(io.open(scandirectory .. coordfilename .. lootfiletype, "w"))

local stringformat = "%+5d%+5d%+5d"
local bytelength = 2
local offset = 2 ^ (bytelength * 8 - 1)
local maxfilesize = 2 ^ 11

--number of averages of geolyzer data to take (better accuracy)
local avgs = 10

local PORT = 50000
--END CONSTANTS====================================

--Minimum Components:
--Geolyzer
--See movemine and sendfile for additional components

local computer = require("computer")
local component = require("component")
local me = require("robot")
local sides = require("sides")
local event = require("event")
local b32 = require("bit32")
local movemine = require("movemine")
local senddata = require("SendFile")

--hold the currently scanning coordinates
local _x = 0
local _y = 0
local _z = 0

--specify the enumerations
local AIR = 0
local IGNORE = 1
local VALUABLE = 2
local LIQUID = 3

local ConsoleAddress
local data

--write to the current loot file
--write to a new loot file if the first one is now too big
local function writevaluestofile(x, y, z, totalbytes, filecount, file, filebase)
	--determine which file ID (could be more than one if too much data)
	totalbytes = totalbytes + 16 --increment the size of the file for the new data
	--the first iteration will close then reopen the same file, but this makes the
	--algorithm work easier
	if math.floor(totalbytes / maxfilesize) > filecount then
		filecount = math.floor(totalbytes / maxfilesize)
		file:close()
		file = assert(io.open(scandirectory .. filebase .. filecount .. lootfiletype, "w"))
	end
	--now that we have the correct file to write to, we can write the data
	file:write(string.format(stringformat .. "\n", x, y, z))
	return totalbytes, filecount, file
end

--perform a scan at the provided coordinates and return the enumeration indicating what the block is
local function performScan(scanx, scanz)
	local columntotal = {}
	for scany = 1,YMAX-YMIN do
		columntotal[scany] = 0
	end
	for a=0,avgs-1 do
		local columncurrent = component.geolyzer.scan(scanx, scanz, YMIN, 1, 1, YMAX-YMIN)
		for scany = 1,YMAX-YMIN do
			columntotal[scany] = columntotal[scany] + columncurrent[scany]
		end
	end
	for scany = 1,YMAX-YMIN do
		columntotal[scany] = columntotal[scany] / avgs
		if columntotal[scany] < 0.1 then
			abytes, acount, af = writevaluestofile(_x+scanx, _y+scany+YMIN-1, _z+scanz, abytes, acount, af, afilebase)
		elseif columntotal[scany] > VALUEBOUNDARY and columntotal[scany] < 50 then
			lbytes, lcount, lf = writevaluestofile(_x+scanx, _y+scany+YMIN-1, _z+scanz, lbytes, lcount, lf, lfilebase)
		elseif columntotal[scany] > 50 then
			wbytes, wcount, wf = writevaluestofile(_x+scanx, _y+scany+YMIN-1, _z+scanz, wbytes, wcount, wf, wfilebase)
		end
	end
end

--determine if we should go home
--low on robot power?
local function worthGoingHome()
	if computer.energy() < MINIMUMPOWER then 
		print("Low Robot Power!")
		return true
	end
	return false
end

local function performAllScans()
--loop through all x,z coordinates within the limits and perform a scan on them
	for scanx = XMIN, XMAX do
		for scanz = ZMIN, ZMAX do
			if worthGoingHome() then
				--cf:write(_x+scanx .. "\n" .. _y .. "\n" .. _z+scanz)
				movemine.returnHome()
				os.sleep(60)
				movemine.moveto(destx, desty, destz)
			end
			--print("Scanning x:" .. scanx .. " z:" .. scanz)
			performScan(scanx, scanz)
		end
	end
end

--MAIN ROUTINE
os.execute("cls")
print("Waiting for Start Signal on Port " .. PORT)
print("Press Ctrl-Alt-C to cancel")
component.modem.open(PORT)
_, _, ConsoleAddress, _, _, destx, desty, destz = event.pull("modem_message")
--accept the command from the main console and get the coordinates to scan from
--TODO check to ensure we've received all valid coordinates (no nils)
print(ConsoleAddress)
os.sleep(1)	--give the console time to prepare to receive the ack
component.modem.send(ConsoleAddress, PORT, "ACK")
--clear all previous results to ensure we don't have any artifacts from it
os.execute("rm -r " .. scandirectory)
os.execute("mkdir " .. scandirectory)
movemine.moveto(destx, desty, destz)
--save the location to so we know where the center is
_x,_y,_z = movemine.getPosition()
cf:write(_x .. "\n" .. _y .. "\n" .. _z)
--cf:close()
performAllScans()
movemine.returnHome()
me.turnAround()
cf:close()
lf:close()
af:close()
wf:close()
allfiles = {}
allfilecount = 1 --this must start at one so sendfilesfromtable works, not sure why
for a=0,acount do
	allfiles[allfilecount] = scandirectory .. afilebase .. a .. lootfiletype
	allfilecount = allfilecount + 1
end
for l=0,lcount do
	allfiles[allfilecount] = scandirectory .. lfilebase .. l .. lootfiletype
	allfilecount = allfilecount + 1
end
for w=0,wcount do
	allfiles[allfilecount] = scandirectory .. wfilebase .. w .. lootfiletype
	allfilecount = allfilecount + 1
end
senddata.send(ConsoleAddress, scandirectory .. coordfilename .. lootfiletype)
senddata.sendfilesfromtable(ConsoleAddress, allfiles)
print("PROGRAM COMPLETE!")