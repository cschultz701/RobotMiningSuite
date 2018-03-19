--OpenComputers Mining v1.0
--ordermine.lua v1.0
--Has robot mine a path determined by findmineorder.lua in order to mine all loot

--for use with findmineorder.lua v1.0

--Commands a listening robot to perform a scan at a user defined relative position.
--This is done remotely so the user can get scan results in the comfort of their own 
--home instead of having to traverse to the robot itself.
--Once the robot completes scanning the commanded area, it will transmit the data back
--to the console as multiple files. 

--CONSTANTS========================================

--used to find the total inventory space to figure out when to go home
local INVENTORYUPGRADES = 2
--determines what the minimum amount of energy is before going back home
local MINIMUMPOWER = 5000

local sides = require("sides")
local lootdropdirection = sides.posz

--RARE CONSTANTS===================================
local commanddirectory = "commandfiles/"
local filetype = ".txt"

local minecommandfilebase = "minecmd"
local PORT = 50001
--END CONSTANTS====================================

local computer = require("computer")
local component = require("component")
local me = require("robot")
local sides = require("sides")
local event = require("event")
local movemine = require("movemine")
local getdata = require("ReceiveFile")
local invctl = component.inventory_controller

local inv = INVENTORYUPGRADES * 16

--determine if we should go home
local function worthGoingHome()
	if computer.energy() < MINIMUMPOWER then 
		print("Low Robot Power!")
		return true
	end
	if me.count(inv-1) > 0 then
		print("Low Inventory Available!")
		return true
	end
	return false
end

local function dumpLoot()
	destslot=1
	movemine.faceDirection(lootdropdirection)
	for s=2,inv do
		while invctl.getStackInSlot(sides.forward, destslot) ~= nil do
			destslot=destslot+1
			if destslot == invctl.getInventorySize(sides.forward) then
				destslot=1
				print("Last slot of destination inventory full")
			end
		end
		me.select(s)
		invctl.dropIntoSlot(sides.forward, destslot)
	end
end

--MAIN ROUTINE
os.execute("cls")
print("Waiting for Start Signal on Port " .. PORT)
print("Press Ctrl-Alt-C to cancel")
component.modem.open(PORT)
--receive the message that says how many command files to execute
_, _, ConsoleAddress, _, _, val = event.pull("modem_message")
--accept the command from the main console and get the coordinates to scan from
print(ConsoleAddress)
os.sleep(1)	--give the console time to prepare to receive the ack
component.modem.send(ConsoleAddress, PORT, "ACK")
--clear all previous results to ensure we don't have any artifacts from it
os.execute("rm -r " .. commanddirectory)
os.execute("mkdir " .. commanddirectory)
getdata.receivefiles()
print("Starting Mining")
me.select(2)
for c=0,val-1 do
	cf = assert(io.open(commanddirectory .. minecommandfilebase .. c .. filetype))
	line = cf:read("*line")
	while not (line == nil) do
		x = tonumber(string.sub(line, 1, 5))
		y = tonumber(string.sub(line, 6, 10))
		z = tonumber(string.sub(line, 11, 15))
		print("Moving to "..x..","..y..","..z)
		line = cf:read("*line")
		movemine.moveto(x,y,z)
		if worthGoingHome() then
			--cf:write(_x+scanx .. "\n" .. _y .. "\n" .. _z+scanz)
			retx,rety,retz=movemine.returnHome()
			dumpLoot()
			--put chargable tool in charger
			me.select(1)
			component.inventory_controller.equip()
			component.inventory_controller.dropIntoSlot(sides.down, 1)
			os.sleep(60)
			--everythings been given time to charge
			component.inventory_controller.suckFromSlot(sides.down, 1)
			component.inventory_controller.equip()
			--movemine.moveto(retx,rety,retz)
		end

	end
	cf:close()

end
movemine.returnHome()
dumpLoot()

