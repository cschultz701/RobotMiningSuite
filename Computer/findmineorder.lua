--OpenComputers Mining v1.0
--findmineorder.lua v1.0
--Analyzes scan results to find the order the robot should mine loot in

--for use with geoscan2.lua v1.0
--This is intended for control server use, but onboard robot is possible

--first find all the clusters so they can be mined as a group
--need to be able to find the cluster ID by a given coordinate
--as well as find the list of coordinates based on a cluster ID

local scandirectory = "scanresults/"
local commanddirectory = "commandfiles/"
local filetype = ".txt"

local lfilebase = "scanValue"
local minecommandfilebase = "minecmd"
local XHOME = -600.5
local YHOME = 31.5
local ZHOME = -895.5
local maxfilesize = 2 ^ 11
local stringformat = "%+5d%+5d%+5d"


--used to define a multi-dimentional array
--this allows us to save a coordinate's cluser ID based on it's dimensions
function newAutotable(dim)
	local MT = {}
	for i=1, dim do
		MT[i] = {__index = function(t,k)
			if i < dim then
				t[k] = setmetatable({}, MT[i+1])
				return t[k]
			end
		end}
	end
	return setmetatable({}, MT[1])
end

--check if any adjacent blocks that have already been checked are part of a cluster already
--if they are, this block is assigned the same cluster
--check -z, then -x, then -y since that's the order that the smallest cluster ID will appear at
--if there is a cluster at -z and a separate cluster at -y, then all portions of the cluster of -y should be remapped to the -z cluster
function checkAdjacent(x, y, z)
	clusterid = clustercount + 1	--get the cluster ID if it is new
	
	--check the adjacent in -z
	if(blocks[x][y][z-1] ~= nil) then
		--there's a cluster here, make this block part of it
		clusterid = blocks[x][y][z-1]
		--increment how many blocks are in that cluster
		clustersizes[clusterid] = clustersizes[clusterid] + 1
		--add the coordinate to the list for this cluster
		coords[clusterid][clustersizes[clusterid]]={x,y,z}
	end
	
	--check the adjacent in -x
	if(blocks[x-1][y][z] ~= nil) then
		--if there was already an adjacent one in -z, then that takes priority, and everything in the cluster in -x must be remapped
		if(clusterid < clustercount + 1 and blocks[x-1][y][z] ~= clusterid) then
			oldcluster = blocks[x-1][y][z]
			print("Resetting cluster "..oldcluster.." of size "..clustersizes[oldcluster])
			for i=1, clustersizes[oldcluster] do
				blocks[coords[oldcluster][i][1]][coords[oldcluster][i][2]][coords[oldcluster][i][3]] = clusterid
				--increment how many blocks are in the new cluster
				clustersizes[clusterid] = clustersizes[clusterid] + 1
				--add the coordinate to the list for this cluster
				coords[clusterid][clustersizes[clusterid]]={coords[oldcluster][i][1],coords[oldcluster][i][2],coords[oldcluster][i][3]}
				coords[oldcluster][i] = nil --cleanup
			end
			clustersizes[oldcluster] = 0
		elseif blocks[x-1][y][z] ~= clusterid then
		--if the cluster in -x isn't already part of this cluster, then this block should be assigned to the cluster in -x
			clusterid = blocks[x-1][y][z]
			--increment how many blocks are in that cluster
			clustersizes[clusterid] = clustersizes[clusterid] + 1
			--add the coordinate to the list for this cluster
			coords[clusterid][clustersizes[clusterid]]={x,y,z}
		end
	end
	
	--check the adjacent in -y
	if(blocks[x][y-1][z] ~= nil) then
		--if there was already an adjacent one in -z or -x, then that takes priority, and everything in the cluster in -y must be remapped
		if(clusterid < clustercount + 1 and blocks[x][y-1][z] ~= clusterid) then
			oldcluster = blocks[x][y-1][z]
			print("Resetting cluster "..oldcluster.." of size "..clustersizes[oldcluster])
			for i=1, clustersizes[oldcluster] do
				blocks[coords[oldcluster][i][1]][coords[oldcluster][i][2]][coords[oldcluster][i][3]] = clusterid
				--increment how many blocks are in the new cluster
				clustersizes[clusterid] = clustersizes[clusterid] + 1
				--add the coordinate to the list for this cluster
				coords[clusterid][clustersizes[clusterid]]={coords[oldcluster][i][1],coords[oldcluster][i][2],coords[oldcluster][i][3]}
				coords[oldcluster][i] = nil --cleanup
			end
			clustersizes[oldcluster] = 0
		elseif blocks[x][y-1][z] ~= clusterid then
		--if the cluster in -y isn't already part of this cluster, then this block should be assigned to the cluster in -y
			clusterid = blocks[x][y-1][z]
			--increment how many blocks are in that cluster
			clustersizes[clusterid] = clustersizes[clusterid] + 1
			--add the coordinate to the list for this cluster
			coords[clusterid][clustersizes[clusterid]]={x,y,z}
		end
	end

	--if the final conclusion is that this is a new cluster, then update the variables appropriately
	if(clusterid == clustercount + 1) then
		clustercount = clustercount + 1		--officially increment the cluster count so a different ID is issued next time
		clustersizes[clusterid] = 1	--this is the first block in this cluster
		coords[clusterid] = {}
		coords[clusterid][1] = {x,y,z}
	end
	blocks[x][y][z] = clusterid	--this cell in the matrix is always set to the resulting cluster ID, regardless if it's been changed since it's declaration
end

function getdistance(c1, c2)
	return math.sqrt(math.pow(c2[1]-c1[1],2)+math.pow(c2[2]-c1[2],2)+math.pow(c2[3]-c1[3],2))
end

--find the closest cluster to the given cluster that hasn't been visited yet
function findclosestcluster(corig)
	closestid = 0
	closestdist = 999999
	for c=1,clustercount do
		if(covered[c]==0) then
			dist = getdistance(coords[corig][1], coords[c][1])	--everything based off the original block of the cluster
			if(dist < closestdist) then
				closestid = c
				closestdist = dist
			end
		end
		--if it's already visited, don't compute the distance
		--corig will appear in the for loop, but by this point it should be marked as visited, so it won't be considered
	end
	return closestid
end

local function writevaluestofile(x, y, z, totalbytes, filecount, file, filebase)
	--determine which file ID (could be more than one if too much data)
	totalbytes = totalbytes + 16 --increment the size of the file for the new data
	--the first iteration will close then reopen the same file, but this makes the
	--algorithm work easier
	if math.floor(totalbytes / maxfilesize) > filecount then
		filecount = math.floor(totalbytes / maxfilesize)
		file:close()
		file = assert(io.open(commanddirectory .. filebase .. filecount .. filetype, "w"))
	end
	--now that we have the correct file to write to, we can write the data
	file:write(string.format(stringformat .. "\n", x, y, z))
	return totalbytes, filecount, file
end

clustercount=0	--holds the number of clusters tracked in the file - basically holds index, so does not reduce if two clusters merge
clustersizes={}	--holds the number of blocks in a cluster
coords={}		--holds the coordinates of each block in a given cluster
blocks=newAutotable(3)	--holds the cluster each coordinate is assigned to
covered={}		--keeps track of which clusters have been visited, 0=not, 1=visted (set clusters of size 0 as visited to avoid visiting them, they've been merged with another cluster)
pacing=40
round=0

--loop through all the value files
print("Number of Value files: ")
val = tonumber(io.read())
for i=0,val-1 do
	lf = assert(io.open(scandirectory .. lfilebase .. i .. filetype))
	line = lf:read("*line")
	while not (line == nil) do
		x = tonumber(string.sub(line, 1, 5))
		y = tonumber(string.sub(line, 6, 10))
		z = tonumber(string.sub(line, 11, 15))
		print("Checking "..x..","..y..","..z)
		checkAdjacent(x, y, z)
		line = lf:read("*line")
		round=round+1
		if round==pacing then
			os.sleep(1)
			round=0
		end
	end
	lf:close()
end

--now that we have the clusters, use a traveling salesman algorithm to get the order we mine each cluster in
--initialize covered to indicate what to look at and what not to
for c=1,clustercount do
	if(clustersizes[c] == 0) then
		covered[c] = 1
	else
		covered[c] = 0
	end

end

--prepare the move order file
bytes = 0
fcount = 0
os.execute("rm -r " .. commanddirectory)
os.execute("mkdir " .. commanddirectory)
mcf = assert(io.open(commanddirectory..minecommandfilebase..fcount..filetype, "w"))

--find the cluster closest to home
--first tell cluster 0 to be home (algorithm starts at cluster 1 normally, so 0 won't overwrite anything)
coords[0] = {}
coords[0][1] = {math.ceil(XHOME),math.ceil(YHOME),math.ceil(ZHOME)}
currentcluster = 0
nextcluster = findclosestcluster(currentcluster)
--loop until there is no next closest cluster - this will happen if all clusters are visited
while nextcluster ~= 0 do
	--write the command to move to the cluster start point
	--remember movemine.lua v0.1 uses relative coordinates only
	print("Setting up cluster " .. nextcluster .. " of size " .. clustersizes[nextcluster])
	bytes, fcount, mcf = writevaluestofile(coords[nextcluster][1][1],
										   coords[nextcluster][1][2],
										   coords[nextcluster][1][3], 
										   bytes, fcount, mcf, minecommandfilebase)
	print((coords[nextcluster][1][1]).."," ..
										   (coords[nextcluster][1][2])..","..
										   (coords[nextcluster][1][3]))
	--TODO-command to mine the entire cluster
	for i=2,clustersizes[nextcluster] do
		bytes, fcount, mcf = writevaluestofile(coords[nextcluster][i][1],
											   coords[nextcluster][i][2],
											   coords[nextcluster][i][3],
											   bytes, fcount, mcf, minecommandfilebase)
		print((coords[nextcluster][i][1])..","..
											   (coords[nextcluster][i][2])..","..
											   (coords[nextcluster][i][3]))
		round=round+1
		if round==pacing then
			os.sleep(1)
			round=0
		end
	end
	--mark the next cluster as visited
	covered[nextcluster] = 1
	--find the cluster to go to next
	currentcluster = nextcluster
	nextcluster = findclosestcluster(currentcluster)
end
print("Command file count: " .. (fcount + 1))
mcf:close()