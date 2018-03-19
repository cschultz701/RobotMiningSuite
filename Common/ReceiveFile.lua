--OpenComputers Mining v1.0
--ReceiveFile.lua v1.0
--Sends files over network to designated address

--For use with SendFile.lua v1.0

--This is a library. It cannot be run standalone.
--.send can be used to send a single file
--.sendfiles can be used to send multiple files. This uses a variable number of arguments.
--.sendfilesfrom table can be used to sent multiple files. This accepts the files as a 
--table of strings.

--CONSTANTS========================================
local PORT = 50000
--END CONSTANTS====================================

local component = require("component")
local event = require("event")
local receivedata = {}

function receivedata.receive()
	component.modem.open(PORT)
	--receive the name
	_, _, sender, _, _, file = event.pull("modem_message")
	print("Receiving " .. file)
	local f = assert(io.open(file, "w"))
	os.sleep(1)
	component.modem.send(sender, PORT, "Ready")
	--receive the data
	_, _, sender, _, _, data = event.pull("modem_message")
	f:write(data)
	os.sleep(1)
	component.modem.send(sender, PORT, "Complete")
	f:close()
end

function receivedata.receiveinparts()
	component.modem.open(PORT)
	--receive the name
	_, _, sender, _, _, file = event.pull("modem_message")
	print("Receiving " .. file)
	local f = assert(io.open(file, "w"))
	os.sleep(1)
	component.modem.send(sender, PORT, "Ready")
	--receive the data
	_, _, sender, _, _, data = event.pull("modem_message")
	while not (data == "Done") do
		f:write(data)
		os.sleep(1)
		component.modem.send(sender, PORT, "Ready")
		_, _, sender, _, _, data = event.pull("modem_message")
	end
	os.sleep(1)
	component.modem.send(sender, PORT, "Complete")
	f:close()
end

function receivedata.receivefiles()
	component.modem.open(PORT)
	--Get Ready
	_, _, sender, _, _, status = event.pull("modem_message")
	os.sleep(1)
	while not (status == "Complete") do
		--print("Sending Ready")
		component.modem.send(sender, PORT, "Ready")
		receivedata.receive()
		--get Done or Ready
		_, _, sender, _, _, status = event.pull("modem_message")
		os.sleep(1)
	end
end

return receivedata