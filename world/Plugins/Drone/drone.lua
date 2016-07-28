
-- queue containing the updates that need to be applied to the minecraft world
UpdateQueue = nil
-- array of build objects
Builds = {}
-- 
SignsToUpdate = {}

-- as a lua array cannot contain nil values, we store references to this object
-- in the "Builds" array to indicate that there is no build at an index
EmptyBuildSpace = {}

-- Tick is triggered by cPluginManager.HOOK_TICK
function updateEveryTick(TimeDelta)
	UpdateQueue:update(MAX_BLOCK_UPDATE_PER_TICK)
end

-- Plugin initialization
function Initialize(Plugin)
	Plugin:SetName("Drone")
	Plugin:SetVersion(1.0)

	UpdateQueue = NewUpdateQueue()

	-- Hooks

	cPluginManager:AddHook(cPluginManager.HOOK_WORLD_STARTED, WorldStarted);
	cPluginManager:AddHook(cPluginManager.HOOK_PLAYER_JOINED, PlayerJoined);
	cPluginManager:AddHook(cPluginManager.HOOK_PLAYER_USING_BLOCK, PlayerUsingBlock);
	cPluginManager:AddHook(cPluginManager.HOOK_CHUNK_GENERATING, OnChunkGenerating);
	cPluginManager:AddHook(cPluginManager.HOOK_PLAYER_FOOD_LEVEL_CHANGE, OnPlayerFoodLevelChange);
	cPluginManager:AddHook(cPluginManager.HOOK_TAKE_DAMAGE, OnTakeDamage);
	cPluginManager:AddHook(cPluginManager.HOOK_WEATHER_CHANGING, OnWeatherChanging);
	cPluginManager:AddHook(cPluginManager.HOOK_SERVER_PING, OnServerPing);
	cPluginManager:AddHook(cPluginManager.HOOK_TICK, updateEveryTick);

	-- Command Bindings

	cPluginManager.BindCommand("/drone", "*", DroneCommand, " - Drone CLI commands")

	Plugin:AddWebTab("Drone",HandleRequest_Drone)

	-- make all players admin
	cRankManager:SetDefaultRank("Admin")

	
	LOG("Initialised " .. Plugin:GetName() .. " v." .. Plugin:GetVersion())

	return true
end

-- updateStats update CPU and memory usage displayed
-- on Build sign (Build identified by id)
function updateStats(id, mem, cpu)
	for i=1, table.getn(Builds)
	do
		if Builds[i] ~= EmptyBuildSpace and Builds[i].id == id
		then
			Builds[i]:updateMemSign(mem)
			Builds[i]:updateCPUSign(cpu)
			break
		end
	end
end

-- getStartStopLeverBuild returns the Build
-- id that corresponds to lever at x,y coordinates
function getStartStopLeverBuild(x, z)
	for i=1, table.getn(Builds)
	do
		if Builds[i] ~= EmptyBuildSpace and x == Builds[i].x + 1 and z == Builds[i].z + 1
		then
			return Builds[i].id
		end
	end
	return ""
end

-- getRemoveButtonBuild returns the Build
-- id and state for the button at x,y coordinates
function getRemoveButtonBuild(x, z)
	for i=1, table.getn(Builds)
	do
		if Builds[i] ~= EmptyBuildSpace and x == Builds[i].x + 2 and z == Builds[i].z + 3
		then
			return Builds[i].id, Builds[i].running
		end
	end
	return "", true
end

-- destroyBuild looks for the first Build having the given id,
-- removes it from the Minecraft world and from the 'Builds' array
function destroyBuild(id)
	LOG("destroyBuild: " .. id)
	-- loop over the Builds and remove the first having the given id
	for i=1, table.getn(Builds)
	do
		if Builds[i] ~= EmptyBuildSpace and Builds[i].id == id
		then
			-- remove the Build from the world
			Builds[i]:destroy()
			-- if the Build being removed is the last element of the array
			-- we reduce the size of the "Build" array, but if it is not, 
			-- we store a reference to the "EmptyBuildSpace" object at the
			-- same index to indicate this is a free space now.
			-- We use a reference to this object because it is not possible to
			-- have 'nil' values in the middle of a lua array.
			if i == table.getn(Builds)
			then
				table.remove(Builds, i)
				-- we have removed the last element of the array. If the array
				-- has tailing empty Build spaces, we remove them as well.
				while Builds[table.getn(Builds)] == EmptyBuildSpace
				do
					table.remove(Builds, table.getn(Builds))
				end
			else
				Builds[i] = EmptyBuildSpace
			end
			-- we removed the Build, we can exit the loop
			break
		end
	end
end

-- updateBuild accepts 3 different states: running, stopped, created
-- sometimes "start" events arrive before "create" ones
-- in this case, we just ignore the update
function updateBuild(id,name,state)
	LOG("Update Build with ID: " .. id .. " state: " .. state)

	-- first pass, to see if the Build is
	-- already displayed (maybe with another state)
	for i=1, table.getn(Builds)
	do
		-- if Build found with same ID, we update it
		if Builds[i] ~= EmptyBuildSpace and Builds[i].id == id
		then
			Builds[i]:setInfos(id,name,state == BUILD_RUNNING)
			Builds[i]:display(state == BUILD_RUNNING)
			LOG("found. updated. now return")
			return
		end
	end

	LOG("Build isn't displayed.")
	-- if Build isn't already displayed, we see if there's an empty space
	-- in the world to display the Build
	x = BUILD_START_X
	index = -1

	for i=1, table.getn(Builds)
	do
		-- use first empty location
		if Builds[i] == EmptyBuildSpace
		then
			LOG("Found empty location: Builds[" .. tostring(i) .. "]")
			index = i
			break
		end
		x = x + BUILD_OFFSET_X			
	end

	build = NewBuild()
	build:init(x,BUILD_START_Z)
	build:setInfos(id,name,state == BUILD_RUNNING)
	build:addGround()
	build:display(state == BUILD_RUNNING)

	if index == -1
		then
			table.insert(Builds, build)
		else
			Builds[index] = build
	end
end

--
function WorldStarted(World)
	y = GROUND_LEVEL
	-- just enough to fit one Build
	-- then it should be dynamic
	for x= GROUND_MIN_X, GROUND_MAX_X
	do
		for z=GROUND_MIN_Z,GROUND_MAX_Z
		do
			setBlock(UpdateQueue,x,y,z,E_BLOCK_WOOL,E_META_WOOL_WHITE)
		end
	end	
end

--
function PlayerJoined(Player)
	-- enable flying
	Player:SetCanFly(true)

	-- refresh Builds
	LOG("player joined")
	r = os.execute("goproxy builds")
	LOG("executed: goproxy builds -> " .. tostring(r))
end

-- 
function PlayerUsingBlock(Player, BlockX, BlockY, BlockZ, BlockFace, CursorX, CursorY, CursorZ, BlockType, BlockMeta)
	LOG("Using block: " .. tostring(BlockX) .. "," .. tostring(BlockY) .. "," .. tostring(BlockZ) .. " - " .. tostring(BlockType) .. " - " .. tostring(BlockMeta))

	-- lever: 1->OFF 9->ON (in that orientation)
	-- lever
	if BlockType == 69
	then
		BuildID = getStartStopLeverBuild(BlockX,BlockZ)
		LOG("Using lever associated with Build ID: " .. BuildID)

		if BuildID ~= ""
		then
			-- stop
			if BlockMeta == 1
			then
				Player:SendMessage("Drone stop " .. string.sub(BuildID,1,8))
				r = os.execute("goproxy exec?cmd=Drone+stop+" .. BuildID)
			-- start
			else 
				Player:SendMessage("Drone start " .. string.sub(BuildID,1,8))
				os.execute("goproxy exec?cmd=Drone+start+" .. BuildID)
			end
		else
			LOG("WARNING: no Drone Build ID attached to this lever")
		end
	end

	-- stone button
	if BlockType == 77
	then
		BuildID, running = getRemoveButtonBuild(BlockX,BlockZ)

		if running
		then
			Player:SendMessage("A running Build can't be removed.")
		else 
			Player:SendMessage("Drone rm " .. string.sub(BuildID,1,8))
			os.execute("goproxy exec?cmd=Drone+rm+" .. BuildID)
		end
	end
end


function OnChunkGenerating(World, ChunkX, ChunkZ, ChunkDesc)
	-- override the built-in chunk generator
	-- to have it generate empty chunks only
	ChunkDesc:SetUseDefaultBiomes(false)
	ChunkDesc:SetUseDefaultComposition(false)
	ChunkDesc:SetUseDefaultFinish(false)
	ChunkDesc:SetUseDefaultHeight(false)
	return true
end


function DroneCommand(Split, Player)

	if table.getn(Split) > 0
	then

		LOG("Split[1]: " .. Split[1])

		if Split[1] == "/Drone"
		then
			if table.getn(Split) > 1
			then
				if Split[2] == "pull" or Split[2] == "create" or Split[2] == "run" or Split[2] == "stop" or Split[2] == "rm" or Split[2] == "rmi" or Split[2] == "start" or Split[2] == "kill"
				then
					-- force detach when running a Build
					if Split[2] == "run"
					then
						table.insert(Split,3,"-d")
					end

					EntireCommand = table.concat(Split, "+")
					-- remove '/' at the beginning
					command = string.sub(EntireCommand, 2, -1)
					
					r = os.execute("goproxy exec?cmd=" .. command)

					LOG("executed: " .. command .. " -> " .. tostring(r))
				end
			end
		end
	end

	return true
end



function HandleRequest_Drone(Request)
	
	content = "[Droneclient]"

	if Request.PostParams["action"] ~= nil then

		action = Request.PostParams["action"]

		-- receiving informations about one Build
		
		if action == "buildsInfo"
		then
			LOG("EVENT - buildsInfo")

			name = Request.PostParams["name"]
			id = Request.PostParams["id"]
			running = Request.PostParams["running"]

			LOG("BuildInfos running: " .. running)

			state = BUILD_SUCCESS
			if running ~= "success" 
			then
				state = BUILD_RUNNING
			end

			updateBuild(id,name,state)
		end

		if action == "startBuild"
		then
			LOG("EVENT - startBuild")

			name = Request.PostParams["name"]
			id = Request.PostParams["id"]

			updateBuild(id,name,BUILD_RUNNING)
		end

		if action == "createBuild"
		then
			LOG("EVENT - createBuild")

			name = Request.PostParams["name"]
			id = Request.PostParams["id"]

			updateBuild(id,name,imageRepo,imageTag,BUILD_CREATED)
		end

		if action == "stopBuild"
		then
			LOG("EVENT - stopBuild")

			name = Request.PostParams["name"]
			id = Request.PostParams["id"]

			updateBuild(id,name,imageRepo,imageTag,BUILD_STOPPED)
		end

		if action == "destroyBuild"
		then
			LOG("EVENT - destroyBuild")
			id = Request.PostParams["id"]
			destroyBuild(id)
		end

		if action == "stats"
		then
			id = Request.PostParams["id"]
			cpu = Request.PostParams["cpu"]
			ram = Request.PostParams["ram"]

			updateStats(id,ram,cpu)
		end


		content = content .. "{action:\"" .. action .. "\"}"

	else
		content = content .. "{error:\"action requested\"}"

	end

	content = content .. "[/Droneclient]"

	return content
end

function OnPlayerFoodLevelChange(Player, NewFoodLevel)
	-- Don't allow the player to get hungry
	return true, Player, NewFoodLevel
end

function OnTakeDamage(Receiver, TDI)
	-- Don't allow the player to take falling or explosion damage
	if Receiver:GetClass() == 'cPlayer'
	then
		if TDI.DamageType == dtFall or TDI.DamageType == dtExplosion then
			return true, Receiver, TDI
		end
	end
	return false, Receiver, TDI
end

function OnServerPing(ClientHandle, ServerDescription, OnlinePlayers, MaxPlayers, Favicon)
	-- Change Server Description
	ServerDescription = "A Drone client for Minecraft, inspired by Dronecraft."
	-- Change favicon
	if cFile:IsFile("/srv/logo.png") then
		local FaviconData = cFile:ReadWholeFile("/srv/logo.png")
		if (FaviconData ~= "") and (FaviconData ~= nil) then
			Favicon = Base64Encode(FaviconData)
		end
	end
	return false, ServerDescription, OnlinePlayers, MaxPlayers, Favicon
end				

-- Make it sunny all the time!
function OnWeatherChanging(World, Weather)
	return true, wSunny
end
