--OpenComputers Mining v1.0
--geoscancontrol.lua v1.0
--Scans requested area and generates files based on results

--for use with geoscan2.lua v1.0
--requires ReceiveFileFile.lua v1.0

--Commands a listening robot to perform a scan at a user defined relative position.
--This is done remotely so the user can get scan results in the comfort of their own 
--home instead of having to traverse to the robot itself.
--Once the robot completes scanning the commanded area, it will transmit the data back
--to the console as multiple files. 

--CONSTANTS========================================
local co = assert(io.open("currentcoordinates.txt", "w"))
scandirectory = "scanresults/"

local PORT = 50000
--END CONSTANTS====================================

local component = require("component")
local getdata = require("ReceiveFile")
local event = require("event")

print("Please provide relative coordinates for Robot to scan at.")
print("Relative X: ")
relx = tonumber(io.read())
print("Relative Y: ")
rely = tonumber(io.read())
print("Relative Z: ")
relz = tonumber(io.read())
print("Sending robot to x=" .. relx .. " y=" .. rely .. " z=" .. relz)
co:write(string.format("relx=%d\nrely=%d\nrelz=%d", relx, rely, relz))
co:close()
--clear all previous results to ensure we don't have any artifacts from it
os.execute("rm -r " .. scandirectory)
os.execute("mkdir " .. scandirectory)
component.modem.open(PORT)
component.modem.broadcast(PORT, relx, rely, relz)
--wait for ack
print("Waiting for command acknowledgment\nPress Ctrl-Alt-C to cancel\n")
_, _, robotaddress, _, _, ack = event.pull("modem_message")
--wait for robot to start sending data
print("Acknowledgement Received")
print("Waiting for scan file transfer\nPress Ctrl-Alt-C to cancel\n")
--receive the coordinate file
getdata.receive()
--get the data
getdata.receivefiles()
print("PROGRAM COMPLETE!")