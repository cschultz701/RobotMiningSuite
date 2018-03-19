--OpenComputers Standard Move/Mine v0.1
--Moves the robot a number of places equal to the provided x, y, and z values provided as arguments.
--Mines area in front of next position to move to ensure the robot does not get stuck

--Minimum Components:
--Inventory Controller Upgrade
--Geolyzer

--Requires Diamond Drill to start in tool slot
--Requires Fortune Pickaxe to start in Inventory Slot 1

--Accepts 3 arguements
--1: the number of blocks to move in the X direction
--2: the number of blocks to move in the Y direction
--3: the number of blocks to move in the Z direction
--TODO investigate enclosing arguments in quotes so negative numbers work (currently considered options instead of arguments)

--This program assumes the intention is to move out to ore
--Moves in the X direction first (east/west)
--then the Z direction (north/south)
--then the Y direction (up/down)

local component = require("component")
local me = require("robot")
local sides = require("sides")
local shell = require("shell")

local movemine={}

function movemine.faceDirection(side)
	print("Turning to " .. side)
	while component.navigation.getFacing() ~= side do
		me.turnRight()
	end
end

function movemine.mineWithTool(side)
	--use geolyzer to determine if we're looking at lapis or diamond
	blocktype = component.geolyzer.analyze(side)["name"]
	if string.find(blocktype, "diamond") or string.find(blocktype, "lapis") then
		special = true
		print("Using Fortune Pickaxe")
	else
		special = false
	end
	if(special)	then --switch with actual logic when geolyzer function is known
		component.inventory_controller.equip()
	end
	if(side == sides.posy) then 
		me.swingUp()
		me.up()
	elseif(side == sides.negy) then
		me.swingDown()
		me.down()
	else
		me.swing()
		me.forward()
	end
	if(special) then
		component.inventory_controller.equip()
	end
end

function movemine.movex(x)
	local direction
	--travel in the X direction
	if x > 0 then
		direction = sides.posx
	else
		direction = sides.negx
	end
	movemine.faceDirection(direction)
	
	--move to the appropriate X coordinate
	print("Moving X by " .. x)
	for i=0, math.abs(x) - 1 do
		movemine.mineWithTool(direction)
	end
end

function movemine.movey(y)
	--move to the appropriate y coordinate
	print("Moving Y by " .. y)
	for i=0, math.abs(y) - 1 do
		if y > 0 then
			movemine.mineWithTool(sides.posy)
		elseif y < 0 then
			movemine.mineWithTool(sides.negy)
		end
	end
end

function movemine.movez(z)
	local direction
	--travel in the X direction
	if z > 0 then
		direction = sides.posz
	else
		direction = sides.negz
	end
	movemine.faceDirection(direction)
	
	--move to the appropriate Z coordinate
	print("Moving Z by " .. z)
	for i=0, math.abs(z) - 1 do
		movemine.mineWithTool(direction)
	end
end
--Main routine

function movemine.go(x, y, z, yfirst, zfirst)
	--parse arguments
	--arg, options = shell.parse(...)
	--local x = tonumber(arg[1])
	--local y = tonumber(arg[2])
	--local z = tonumber(arg[3])
	----set values negative if required (0=positive, 1=negative)
	--x = x * (tonumber(arg[4]) - 0.5) * -2
	--y = y * (tonumber(arg[5]) - 0.5) * -2
	--z = z * (tonumber(arg[6]) - 0.5) * -2
	print("Moving by " .. x .. ", " .. y .. ", " .. z)
	
	--prioritize y being close to home first
	if(yfirst) then
		movemine.movey(y)
	end
	
	--next keep z close to home
	if(zfirst) then
		movemine.movez(z)
	end
	
	movemine.movex(x)
	
	if(not zfirst) then
		movemine.movez(z)
	end
	
	if(not yfirst) then
		movemine.movey(y)
	end
end

return movemine