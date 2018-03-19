--OpenComputers Mining v0.1
--Creates a 3D map of the area above and below the robot

--Robot waits until it receives a request from the main console
--which is sent via broadcast over the wireless network.
--Upon receiving, it responds with a confirmation, this provides
--both sides with an address (to use send instead of broadcast).
--The main console may be allowed to choose which robot to
--communicate with if multiple are available.
--Quantizes the geolyzer results of each block to determine
--what is likely present at the block, then transmits the
--information back to the main computer via the wireless
--network.

--CONSTANTS========================================
--identifies the home coordinates (use component.navigation.getPosition() to get this)
local XHOME = -37.5
local YHOME = 84.5
local ZHOME = -63.5

--determines the relative limits where the robot stops mining
local XLIMIT = 4
local YLIMIT = 0
local ZLIMIT = 4

--Determine the network port for communication
local PORT = 1

--geolyzer always says air = 0
--anything more than 0 is a block
--Stone = 1.5 +/- noise
--Lead = 2 +/- noise
--All other ores tried = 3 +/- noise
--Water/Lava = 100 +/- noise
local VALUEBOUNDARY = 1.75

--determines what the minimum amount of energy is before going back home
local MINIMUMPOWER = 5000
--RARE CONSTANTS===================================

--file to save loot locations to
local lf = assert(io.open("lootresults.txt", "w"))
--file to save air locations to
local af = assert(io.open("airresults.txt", "w"))
--file to save water/lava locations to
local wf = assert(io.open("waterresults.txt", "w"))

--number of averages of geolyzer data to take (better accuracy)
local avgs = 10

local ymax = 32

--END CONSTANTS====================================

--Minimum Components:
--Geolyzer
--Wireless network card
--Navigation Upgrade

--X and Z of the robot might not correspond to X and Z of minecraft
--Z+ is in front of the robot from its starting location
--X+ is to the left of the robot from its starting location

local computer = require("computer")
local component = require("component")
local me = require("robot")
local sides = require("sides")
local event = require("event")

--hold the robots coordinates
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

local go = true		--determines if the next z movement should be forward (going) or backward (coming)
local limitreached = false	--determines if the program is done as all requested scanning is complete

local function performScan()
	local columntotal = {}
	--initialize array/table
	for y=1,ymax do
		columntotal[y] = 0
	end
	for a=0,avgs-1 do
		local columncurrent = component.geolyzer.scan(0, 0, -32, 1, 1, 32)
		for y=1,ymax do
			columntotal[y] = columntotal[y] + columncurrent[y]
		end
	end
	for y=1,ymax do
		columntotal[y] = columntotal[y] / avgs
		if columntotal[y] > VALUEBOUNDARY and columntotal[y] < 90 then
			lf:write(string.format("x,%+2d,z\n")
		end
	end
end

--go back home for whatever reason (low power, done)
local function returnHome()
	--prep for going home
	x,y,z = component.navigation.getPosition()
	print("Returning home from x=" .. x .. " y=" .. y .. " z=" .. z)
	
	--first return to x = 0 since all y and z coordinates along this x should be empty (already run)
	if go then
		me.turnRight()
	else
		me.turnLeft()
	end
	while math.abs(x - XHOME) > 0 do
		me.swing()	--if gravel falls in the path
		me.forward()
		x,y,z = component.navigation.getPosition()
	end
	--now do z since that will be the next section to know to be done
	me.turnRight()
	while math.abs(z - ZHOME) > 0 do
		me.swing() --if gravel falls in the path
		me.forward()
		x,y,z = component.navigation.getPosition()
	end
	--last do y
	while math.abs(y - YHOME) > 0 do
		me.down()
		x,y,z = component.navigation.getPosition()
	end
	me.turnAround()
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

--determines the next place to move, harvests in that direction, and moves there
local function doNextMove()
	x,y,z = component.navigation.getPosition()
	if (go and math.abs(z - ZHOME) < ZLIMIT) or (not go and math.abs(z - ZHOME) > 0) then
	--otherwise see if next movement is a z movement (next most common)
		me.swing()
		me.forward()
		performScan()
	elseif math.abs(x - XHOME) < XLIMIT then
	--otherwise it is an x movement so long as we aren't at the limit
		if go then
			me.turnLeft()
		else
			me.turnRight()
		end
		me.swing()
		me.forward()
		performScan()
		if go then
			me.turnLeft()
		else
			me.turnRight()
		end
		go = not go
	else
	--this should only happen if we are at the limits of all three coordinates
		limitreached = true
		print("Scanning limits reached. Program finishing.")
		returnHome()
	end
end

--MAIN ROUTINE
os.execute("cls")
print("Waiting for Start Signal on Port " .. PORT)
print("Press Ctrl-Alt-C to cancel")
component.modem.open(PORT)
_, _, ConsoleAddress, _, _ = event.pull("modem_message")
print(ConsoleAddress)
while not limitreached do
	if worthGoingHome() then
		returnHome()
	end
	doNextMove()	--this will set limitreached if necessary
end

returnHome()
me.turnAround()
lf:close()
print("PROGRAM COMPLETE!")