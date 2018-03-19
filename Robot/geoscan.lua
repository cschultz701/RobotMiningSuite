--OpenComputers Mining v1.0
--geoscan2.lua v1.0
--Scans requested area and generates files based on results

--for use with geoscancontrol.lua v1.0
--requires SendFile.lua v1.0
--requires movemine.lua v0.1

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
--identifies the home coordinates (use component.navigation.getPosition() to get this)
local XHOME = -600.5
local YHOME = 31.5
local ZHOME = -895.5

--determines the relative limits where the robot stops mining
local XMIN = -2 ---23
local YMIN = -32
local ZMIN = -2 ---23
local XMAX = 2 --23
local YMAX = 32
local ZMAX = 2 --23

--geolyzer always says air = 0
--anything more than 0 is a block
--Stone = 1.5 +/- noise
--Lead = 2 +/- noise
--All other ores tried = 3 +/- noise
--Water/Lava = 100 +/- noise
local VALUEBOUNDARY = 2.8

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

local computer = require("computer")
local component = require("component")
local me = require("robot")
local sides = require("sides")
local event = require("event")
local b32 = require("bit32")
local movemine = require("movemine")
local senddata = require("SendFile")

--hold the currently scanning coordinates
local x = 0
local y = 0
local z = 0

--specify the enumerations
local AIR = 0
local IGNORE = 1
local VALUABLE = 2
local LIQUID = 3

local ConsoleAddress
local data

--encapsulate data into binary
--note: stores in little endian
local function getdatabytes(x, y, z)
	x = x + offset
	xbytes = {}
	for b = 0,bytelength-1 do
		xbytes[b] = b32.band(b32.rshift(x, 8 * b),255)
	end
	y = y + offset
	ybytes = {}
	for b = 0,bytelength-1 do
		ybytes[b] = b32.band(b32.rshift(y, 8 * b),255)
	end
	z = z + offset
	zbytes = {}
	for b = 0,bytelength-1 do
		zbytes[b] = b32.band(b32.rshift(z, 8 * b),255)
	end
	return xbytes, ybytes, zbytes
end

--write to the current loot file
--write to a new loot file if the first one is now too big
local function writebytestofile(xbytes, ybytes, zbytes, totalbytes, filecount, file, filebase)
	--determine which file ID (could be more than one if too much data)
	totalbytes = totalbytes + bytelength * 3 --increment the size of the file for the new data
	--the first iteration will close then reopen the same file, but this makes the
	--algorithm work easier
	if math.floor(totalbytes / maxfilesize) > filecount then
		filecount = math.floor(totalbytes / maxfilesize)
		file:close()
		file = assert(io.open(scandirectory .. filebase .. filecount .. lootfiletype, "w"))
	end
	--now that we have the correct file to write to, we can write the data
	for b=0,bytelength-1 do
		file:write(xbytes[b])
	end
	for b=0,bytelength-1 do
		file:write(ybytes[b])
	end
	for b=0,bytelength-1 do
		file:write(zbytes[b])
	end
	return totalbytes, filecount, file
end

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
			--af:write(string.format(stringformat .. "\n", x+scanx, y+scany+YMIN, z+scanz))
			xbytes, ybytes, zbytes = getdatabytes(x+scanx, y+scany+YMIN, z+scanz)
			--abytes, acount, af = writebytestofile(xbytes, ybytes, zbytes, abytes, acount, af, afilebase)
			abytes, acount, af = writevaluestofile(x+scanx, y+scany+YMIN, z+scanz, abytes, acount, af, afilebase)
		elseif columntotal[scany] > VALUEBOUNDARY and columntotal[scany] < 50 then
			--lf:write(string.format(stringformat .. " %5f" .. "\n", x+scanx, y+scany+YMIN, z+scanz, columntotal[scany]))
			xbytes, ybytes, zbytes = getdatabytes(x+scanx, y+scany+YMIN, z+scanz)
			--lbytes, lcount, lf = writebytestofile(xbytes, ybytes, zbytes, lbytes, lcount, lf, lfilebase)
			lbytes, lcount, lf = writevaluestofile(x+scanx, y+scany+YMIN, z+scanz, lbytes, lcount, lf, lfilebase)
		elseif columntotal[scany] > 50 then
			--wf:write(string.format(stringformat .. "\n", x+scanx, y+scany+YMIN, z+scanz))
			xbytes, ybytes, zbytes = getdatabytes(x+scanx, y+scany+YMIN, z+scanz)
			--wbytes, wcount, wf = writebytestofile(xbytes, ybytes, zbytes, wbytes, wcount, wf, wfilebase)
			wbytes, wcount, wf = writevaluestofile(x+scanx, y+scany+YMIN, z+scanz, wbytes, wcount, wf, wfilebase)
		end
	end
end

local function moveto(destx, desty, destz)
	x,y,z = component.navigation.getPosition()
	local yfirst, zfirst
	if((y > YHOME and desty < 0) or (y < YHOME and desty > 0)) then
		yfirst = true
	else
		yfirst = false
	end
	if((z > ZHOME and destz < 0) or (z < ZHOME and destz > 0)) then
		zfirst = true
	else
		zfirst = false
	end
	movemine.go(destx, desty, destz, yfirst, zfirst)
end

--go back home for whatever reason (low power, done)
local function returnHome()
	--prep for going home
	x,y,z = component.navigation.getPosition()
	print("Returning home from x=" .. x .. " y=" .. y .. " z=" .. z)
	
	moveto(XHOME-x, YHOME-y, ZHOME-z)
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
	x,y,z = component.navigation.getPosition()
	for scanx = XMIN, XMAX do
		for scanz = ZMIN, ZMAX do
			if worthGoingHome() then
				returnHome()
				return
			end
			print("Scanning x:" .. scanx .. " z:" .. scanz)
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
moveto(destx, desty, destz)
--save the location to so we know where the center is
x,y,z = component.navigation.getPosition()
cf:write(x .. "\n" .. y .. "\n" .. z)
cf:close()
performAllScans()
returnHome()
me.turnAround()
lf:close()
af:close()
wf:close()
allfiles = {}
allfilecount = 1
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