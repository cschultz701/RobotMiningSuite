--OpenComputers Mining v1.0
--SendFile.lua v1.0
--Sends files over network to designated address

--For use with ReceiveFile.lua v1.0

--This is a library. It cannot be run standalone.
--.send can be used to send a single file
--.sendfiles can be used to send multiple files. This uses a variable number of arguments.
--.sendfilesfrom table can be used to sent multiple files. This accepts the files as a 
--table of strings.

--CONSTANTS========================================
local PORT = 50000
local buffersize = 2^12
--END CONSTANTS====================================

local component = require("component")
local event = require("event")
local sendfile = {}

function sendfile.send(address, file)
	component.modem.open(PORT)
	local f = assert(io.open(file))
	
	print("Sending file " .. file .. " to address " .. address)
	component.modem.send(address, PORT, file)	--send the name
	event.pull("modem_message")	--receive the "Ready"
	os.sleep(1)	--give the receiver time to prep for the next message
	data = f:read("*all")
	component.modem.send(address, PORT, data)
	f:close()
	event.pull("modem_message")	--receive the "Complete"
end

function sendfile.sendinparts(address, file)
	component.modem.open(PORT)
	local f = assert(io.open(file))
	
	print("Sending file " .. file .. " to address " .. address)
	component.modem.send(address, PORT, file)	--send the name
	event.pull("modem_message")	--receive the "Ready"
	os.sleep(1)	--give the receiver time to prep for the next message
	data = f:read(buffersize)
	while not (data == nil) do
		component.modem.send(address, PORT, data)
		event.pull("modem_message")	--receive the "Ready"
		os.sleep(1)	--give the receiver time to prep for the next message
		data = f:read(buffersize)
	end
	component.modem.send(address, PORT, "Done")
	f:close()
	event.pull("modem_message")	--receive the "Complete"
end	

function sendfile.sendfiles(address, ...)
	component.modem.open(PORT)
	arg = table.pack(...)
	for index, file in ipairs(arg) do
		--print("Sending Ready")
		component.modem.send(address, PORT, "Ready")
		event.pull("modem_message")	--receive the "Ready"
		os.sleep(1)	--give the receiver time to prep for the next message
		sendfile.send(address, file)
		os.sleep(1)
	end
	component.modem.send(address, PORT, "Complete")
end

function sendfile.sendfilesfromtable(address, files)
	component.modem.open(PORT)
	for index, file in ipairs(files) do
		--print("Sending Ready")
		component.modem.send(address, PORT, "Ready")
		event.pull("modem_message")	--receive the "Ready"
		os.sleep(1)	--give the receiver time to prep for the next message
		sendfile.send(address, file)
		os.sleep(1)
	end
	component.modem.send(address, PORT, "Complete")
end

return sendfile