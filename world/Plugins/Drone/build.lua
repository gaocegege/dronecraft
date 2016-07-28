-- Build object is the representation of a Docker
-- Build in the Minecraft world

-- constant variables
BUILD_SUCCESS = 0
BUILD_FAILED = 1
BUILD_PENDING = 2
BUILD_RUNNING = 3

-- NewBuild returns a Build object,
-- representation of a Drone Build in
-- the Minecraft world
function NewBuild()
	b = {
			displayed = false, 
			x = 0, 
			z = 0, 
			name="",
			id="",
			running=false,
			init=Build.init,
			setInfos=Build.setInfos,
			destroy=Build.destroy,
			display=Build.display,
			updateMemSign=Build.updateMemSign,
			updateCPUSign=Build.updateCPUSign,
			addGround=Build.addGround
		}
	return b
end

Build = {displayed = false, x = 0, z = 0, name="",id="",imageRepo="",imageTag="",running=false}

-- Build:init sets Build's position
function Build:init(x,z)
	self.x = x
	self.z = z
	self.displayed = false	
end

-- Build:setInfos sets Build's id, name, and running state
function Build:setInfos(id,name,running)
	self.id = id
	self.name = name
	self.running = running
end

-- Build:destroy removes all blocks of the 
-- Build, it won't be visible on the map anymore
function Build:destroy(running)
	X = self.x+2
	Y = GROUND_LEVEL+2
	Z = self.z+2
	LOG("Exploding at X:" .. X .. " Y:" .. Y .. " Z:" .. Z)
	local World = cRoot:Get():GetDefaultWorld()
	World:BroadcastSoundEffect("random.explode", X, Y, Z, 1, 1)
	World:BroadcastParticleEffect("hugeexplosion",X, Y, Z, 0, 0, 0, 1, 1)

	-- if a block is removed before it's button/lever/sign, that object will drop
	-- and the player can collect it. Remove these first

	-- lever
	digBlock(UpdateQueue,self.x+1,GROUND_LEVEL+3,self.z+1)
	-- signs
	digBlock(UpdateQueue,self.x+3,GROUND_LEVEL+2,self.z-1)
	digBlock(UpdateQueue,self.x,GROUND_LEVEL+2,self.z-1)
	digBlock(UpdateQueue,self.x+1,GROUND_LEVEL+2,self.z-1)
	-- torch
	digBlock(UpdateQueue,self.x+1,GROUND_LEVEL+3,self.z+1)
	--button
	digBlock(UpdateQueue,self.x+2,GROUND_LEVEL+3,self.z+2)

	-- rest of the blocks
	for py = GROUND_LEVEL+1, GROUND_LEVEL+4
	do
		for px=self.x-1, self.x+4
		do
			for pz=self.z-1, self.z+5
			do
				digBlock(UpdateQueue,px,py,pz)
			end	
		end
	end
end

-- Build:display displays all Build's blocks
-- Blocks will be blue if the Build is running, 
-- orange otherwise.
function Build:display(running)

	metaPrimaryColor = E_META_WOOL_LIGHTBLUE
	metaSecondaryColor = E_META_WOOL_BLUE

	if running == false 
	then
		metaPrimaryColor = E_META_WOOL_ORANGE
		metaSecondaryColor = E_META_WOOL_RED
	end

	self.displayed = true
	
	for px=self.x, self.x+3
	do
		for pz=self.z, self.z+4
		do
			setBlock(UpdateQueue,px,GROUND_LEVEL + 1,pz,E_BLOCK_WOOL,metaPrimaryColor)
		end
	end

	for py = GROUND_LEVEL+2, GROUND_LEVEL+3
	do
		setBlock(UpdateQueue,self.x+1,py,self.z,E_BLOCK_WOOL,metaPrimaryColor)

		-- leave empty space for the door
		-- setBlock(UpdateQueue,self.x+2,py,self.z,E_BLOCK_WOOL,metaPrimaryColor)
		
		setBlock(UpdateQueue,self.x,py,self.z,E_BLOCK_WOOL,metaPrimaryColor)
		setBlock(UpdateQueue,self.x+3,py,self.z,E_BLOCK_WOOL,metaPrimaryColor)

		setBlock(UpdateQueue,self.x,py,self.z+1,E_BLOCK_WOOL,metaSecondaryColor)
		setBlock(UpdateQueue,self.x+3,py,self.z+1,E_BLOCK_WOOL,metaSecondaryColor)

		setBlock(UpdateQueue,self.x,py,self.z+2,E_BLOCK_WOOL,metaPrimaryColor)
		setBlock(UpdateQueue,self.x+3,py,self.z+2,E_BLOCK_WOOL,metaPrimaryColor)

		setBlock(UpdateQueue,self.x,py,self.z+3,E_BLOCK_WOOL,metaSecondaryColor)
		setBlock(UpdateQueue,self.x+3,py,self.z+3,E_BLOCK_WOOL,metaSecondaryColor)

		setBlock(UpdateQueue,self.x,py,self.z+4,E_BLOCK_WOOL,metaPrimaryColor)
		setBlock(UpdateQueue,self.x+3,py,self.z+4,E_BLOCK_WOOL,metaPrimaryColor)

		setBlock(UpdateQueue,self.x+1,py,self.z+4,E_BLOCK_WOOL,metaPrimaryColor)
		setBlock(UpdateQueue,self.x+2,py,self.z+4,E_BLOCK_WOOL,metaPrimaryColor)
	end

	-- torch
	setBlock(UpdateQueue,self.x+1,GROUND_LEVEL+3,self.z+3,E_BLOCK_TORCH,E_META_TORCH_ZP)

	-- start / stop lever
	setBlock(UpdateQueue,self.x+1,GROUND_LEVEL + 3,self.z + 2,E_BLOCK_WALLSIGN,E_META_CHEST_FACING_XP)
	updateSign(UpdateQueue,self.x+1,GROUND_LEVEL + 3,self.z + 2,"","START/STOP","---->","",2)


	if running
	then
		setBlock(UpdateQueue,self.x+1,GROUND_LEVEL+3,self.z+1,E_BLOCK_LEVER,1)
	else
		setBlock(UpdateQueue,self.x+1,GROUND_LEVEL+3,self.z+1,E_BLOCK_LEVER,9)
	end


	-- remove button

	setBlock(UpdateQueue,self.x+2,GROUND_LEVEL + 3,self.z + 2,E_BLOCK_WALLSIGN,E_META_CHEST_FACING_XM)
	updateSign(UpdateQueue,self.x+2,GROUND_LEVEL + 3,self.z + 2,"","REMOVE","---->","",2)

	setBlock(UpdateQueue,self.x+2,GROUND_LEVEL+3,self.z+3,E_BLOCK_STONE_BUTTON,E_BLOCK_BUTTON_XM)


	-- door
	-- Cuberite bug with Minecraft 1.8 apparently, doors are not displayed correctly
	-- setBlock(UpdateQueue,self.x+2,GROUND_LEVEL+2,self.z,E_BLOCK_WOODEN_DOOR,E_META_CHEST_FACING_ZM)


	for px=self.x, self.x+3
	do
		for pz=self.z, self.z+4
		do
			setBlock(UpdateQueue,px,GROUND_LEVEL + 4,pz,E_BLOCK_WOOL,metaPrimaryColor)
		end	
	end

	setBlock(UpdateQueue,self.x+3,GROUND_LEVEL + 2,self.z - 1,E_BLOCK_WALLSIGN,E_META_CHEST_FACING_ZM)
	updateSign(UpdateQueue,self.x+3,GROUND_LEVEL + 2,self.z - 1,string.sub(self.id,1,8),self.name,self.imageRepo,self.imageTag,2)

	-- Mem sign
	setBlock(UpdateQueue,self.x,GROUND_LEVEL + 2,self.z - 1,E_BLOCK_WALLSIGN,E_META_CHEST_FACING_ZM)

	-- CPU sign
	setBlock(UpdateQueue,self.x+1,GROUND_LEVEL + 2,self.z - 1,E_BLOCK_WALLSIGN,E_META_CHEST_FACING_ZM)
end


-- Build:updateMemSign updates the mem usage
-- value displayed on Build's sign
function Build:updateMemSign(s)
	updateSign(UpdateQueue,self.x,GROUND_LEVEL + 2,self.z - 1,"Mem usage","",s,"")
end

-- Build:updateCPUSign updates the mem usage
-- value displayed on Build's sign
function Build:updateCPUSign(s)
	updateSign(UpdateQueue,self.x+1,GROUND_LEVEL + 2,self.z - 1,"CPU usage","",s,"")
end

-- Build:addGround creates ground blocks
-- necessary to display the Build
function Build:addGround()
	if GROUND_MIN_X > self.x - 2
	then 
		OLD_GROUND_MIN_X = GROUND_MIN_X
		GROUND_MIN_X = self.x - 2
		for x= GROUND_MIN_X, OLD_GROUND_MIN_X
		do
			for z=GROUND_MIN_Z,GROUND_MAX_Z
			do
				setBlock(UpdateQueue,x,y,z,E_BLOCK_WOOL,E_META_WOOL_WHITE)
			end
		end	
	end
end
