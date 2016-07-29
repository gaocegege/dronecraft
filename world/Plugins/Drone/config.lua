-- config sets all configuration variables
-- for the Docker plugin.

-- X,Z positions to draw first BUILD
BUILD_START_X = -3
BUILD_START_Z = 2
-- offset to draw next BUILD
BUILD_OFFSET_X = -6

-- the generated Minecraft world is just
-- a white horizontal plane generated at
-- this specific level
GROUND_LEVEL = 63

-- defines minimum surface to place one BUILD
GROUND_MIN_X = BUILD_START_X - 200
GROUND_MAX_X = BUILD_START_X + 500
GROUND_MIN_Z = -4
GROUND_MAX_Z = BUILD_START_Z + 6

-- block updates are queued, this defines the 
-- maximum of block updates that can be handled
-- in one single tick, for performance issues.
MAX_BLOCK_UPDATE_PER_TICK = 50
