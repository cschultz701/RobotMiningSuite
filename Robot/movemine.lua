--OpenComputers Standard Move/Mine v1.0
--Moves the robot a number of places equal to the provided x, y, and z values provided as arguments.
--Mines area in front of next position to move to ensure the robot does not get stuck

--Minimum Components:
--Inventory Controller Upgrade
--Geolyzer
--Navigation Upgrade

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

--identifies the home coordinates (use component.navigation.getPosition() to get this)
local XHOME = -319
local YHOME = 56
local ZHOME = 193

function movemine.faceDirection(side)
	print("Turning to " .. side)
	while component.navigation.getFacing() ~= side do
		me.turnRight()
	end
end

function movemine.truncate(val)
	if val > 0 then
		return math.floor(val)
	else
		return math.ceil(val)
	end
end

function movemine.getPosition()
	x,y,z=component.navigation.getPosition()
	return movemine.truncate(x),movemine.truncate(y),movemine.truncate(z)
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
	
	--determine the location so we can see if we successfully moved the distance we need
	curx,cury,curz = movemine.getPosition()
	--move to the appropriate X coordinate
	print("Moving X by " .. x)
	for i=0, math.abs(x) - 1 do
		movemine.mineWithTool(direction)
	end
	newx,newy,newz = movemine.getPosition()
	return x+curx-newx
end

function movemine.movey(y)
	--determine the location so we can see if we successfully moved the distance we need
	curx,cury,curz = movemine.getPosition()
	--move to the appropriate y coordinate
	print("Moving Y by " .. y)
	for i=0, math.abs(y) - 1 do
		if y > 0 then
			movemine.mineWithTool(sides.posy)
		elseif y < 0 then
			movemine.mineWithTool(sides.negy)
		end
	end
	newx,newy,newz = movemine.getPosition()
	return y+cury-newy
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
	
	--determine the location so we can see if we successfully moved the distance we need
	curx,cury,curz = movemine.getPosition()
	--move to the appropriate Z coordinate
	print("Moving Z by " .. z)
	for i=0, math.abs(z) - 1 do
		movemine.mineWithTool(direction)
	end
	newx,newy,newz = movemine.getPosition()
	return z+curz-newz
end

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
	
	remainx = 0
	remainy = 0
	remainz = 0
	
	--prioritize y being close to home first
	if(yfirst) then
		remainy=movemine.movey(y)
	end
	
	--next keep z close to home
	if(zfirst) then
		remainz=movemine.movez(z)
		--try to move any y distance that wasn't successfully moved
		if(yfirst and remainy ~= 0) then
			remainy=movemine.movey(remainy)
		end
	end
	
	remainx=movemine.movex(x)
	--try to move any y distance that wasn't successfully moved
	if(yfirst and remainy ~= 0) then
		remainy=movemine.movey(remainy)
	end
	--try to move any z distance that wasn't successfully moved
	if(zfirst and remainz ~= 0) then
		remainz=movemine.movez(remainz)
	end

	if(not zfirst) then
		remainz=movemine.movez(z)
		if(yfirst and remainy ~= 0) then
			remainy=movemine.movey(remainy)
		end
		if(remainx ~= 0) then
			remainx=movemine.movex(remainx)
		end
	end
	
	if(not yfirst) then
		movemine.movey(y)
		if(zfirst and remainz ~= 0) then
			remainz=movemine.movez(remainz)
		end
		if(remainx ~= 0) then
			remainx=movemine.movex(remainx)
		end
		if(not zfirst and remainz ~= 0) then
			remainz=movemine.movez(remainz)
		end
	end
end

function movemine.moveby(destx, desty, destz)
	x,y,z = movemine.getPosition()
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

function movemine.moveto(destx, desty, destz)
	x,y,z = movemine.getPosition()
	local yfirst, zfirst
	if((y > YHOME and desty < y) or (y < YHOME and desty > y)) then
		yfirst = true
	else
		yfirst = false
	end
	if((z > ZHOME and destz < z) or (z < ZHOME and destz > z)) then
		zfirst = true
	else
		zfirst = false
	end
	attempt = 0
	while(destx ~= math.ceil(x) or
	   desty ~= math.ceil(y) or
	   destz ~= math.ceil(z)) and attempt < 3 do
		print(math.ceil(x)..","..math.ceil(y)..","..math.ceil(z))
		movemine.go(destx-math.ceil(x), desty-math.ceil(y), destz-math.ceil(z), yfirst, zfirst)
		x,y,z = movemine.getPosition()
		attempt = attempt+1
	end
end

--go back home for whatever reason (low power, done)
function movemine.returnHome()
	--prep for going home
	x,y,z = movemine.getPosition()
	print("Returning home from x=" .. x .. " y=" .. y .. " z=" .. z)
	
	movemine.moveto(XHOME, YHOME, ZHOME)
	--return x-math.ceil(XHOME),y-math.ceil(YHOME),z-math.ceil(ZHOME)
end

return movemine