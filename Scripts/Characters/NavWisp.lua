-- Script for the NavWisp character's movement and animation
-- (by Red Agliator)

include("Scripts/Core/Common.lua")

if NavWisp == nil then
	NavWisp = EternusEngine.GameObjectClass.Subclass("NavWisp")
end

------------------------------------------------------------------------------

-- Class variables, if any (see :Constructor() for instance variables)

-- These act as constants
NavWisp.m_capsuleDimensions	= 
{
	Height 	= 0.1,
	Radius 	= 0.1
}

-------------------------------------------------------------------------------
-- Called from C++ when a new instance of this class is created
--		Initialize instance variables to defaults here
--		Read in arguments from object.txt file, if any
-- Note: when we reload scripts, we don't re-call the constructors, so changes made
-- here will not affect any currently existing objects 
function NavWisp:Constructor( args )
	-- Set instance variables to default values
	self.m_homeLocation = nil 	-- what location do we always point to?
	self.m_player = nil 		-- which player are we helping?
	self.m_playerdistance = 6.5	-- the number of units away from the player
	-- 		Instance variables that control the character's movement style
	-- 		These use the same names as in AICharacter.lua to make it easier to 
	--		add the state machine back into the mix
	self.m_follow 			= false 	-- move when the player does?
	self.m_maxspeed 		= 9.0		-- Max movement speed in the state (units/second)
	self.m_maxacceleration 	= 0.6		-- Acceleration used to reach the max speed (units/sec/sec aka speed/sec)
	self.m_maxdeceleration	= 0.8		-- The deceleration used to come to a stop (POSITIVE NUMBER, units/sec/sec aka speed/sec)
	self.m_turnrate 		= 10000.0	-- degrees per second
	self.m_closeenough		= 0.5		-- Units from the target position that counts as "I'm close enough to my target to stop"

	-- DEBUG temporarily turned off to make testing easier
	-- Use the arguments section from the text file (if it exists)
	if args ~= nil then
		-- NKPrint("[RA_L] Found arguments in the definition text file:\n")
		-- -- print the argument names
		-- for k,v in pairs(args) do
		--   NKPrint("\t"..k.."\n")
		-- end
		if args.maxspeed then
			self.m_maxspeed = args.maxspeed
		end
		if args.acceleration then
			self.m_maxacceleration = args.acceleration
		end
		if args.turnrate then
			self.m_turnrate = args.turnrate
		end
		if args.deceleration then
			self.m_maxdeceleration = args.deceleration
		end
		if args.closeenough then
			self.m_closeenough = args.closeenough
		end
		if args.playerdistance then
			self.m_playerdistance = args.playerdistance
		end
		if args.follow then
			self.m_follow = args.follow
		end
	end
end
	
-------------------------------------------------------------------------------
-- Called once from the Engine after the GameObject is constructed.
function NavWisp:PostLoad( )
	if NavWisp.__super.PostLoad ~= nil then
		NavWisp.__super.PostLoad(self)
	end

	-- from the original Wisp.lua 
	self.u_gfx = self.object:NKGetAnimatedGraphics()

	-- Turn this into a character
	if Eternus.IsServer then
		-- RA question: should this be deleted for an 'ethereal' object?
		-- Create a capsule for this character
		self.m_controller = CharacterController.new(self.object)

		-- Tie it to our GameObject (C++ takes memory ownership here as well).
		self:NKSetController(self.m_controller)

		-- RA question: Why does switching to an entity controller make the movement so weird?
		self.m_controller:NKSwitchToEntityController(0)
		
		-- RA question: 
		--		1) NKSetControllerCapsuleSize isn't in the API docs--what is it?
		-- RA question: should this be deleted for an 'ethereal' object?
		-- Set the capsule dimensions
		self:NKSetControllerCapsuleSize(self.m_capsuleDimensions.Height, self.m_capsuleDimensions.Radius)

		-- The next two lines do NOT disable collisions 
		self:NKSetPhysics(RigidBodyComponent.NKCreateCapsule(self.object, self.m_capsuleDimensions.Height, self.m_capsuleDimensions.Radius))
		self:NKGetPhysics():NKDisableCollisions()		

		-- RA question: are these needed? are there any missing?

		self.m_controller:EnableFlying()
		self.m_controller:SetGravity(vec3.new(0))

	elseif Eternus.IsClient then
		-- RA question: should this be deleted for an 'ethereal' object?
		-- Create a capsule for this character

		-- The next two lines do NOT disable collisions (or at least not always)
		self:NKSetPhysics(RigidBodyComponent.NKCreateCapsule(self.object, self.m_capsuleDimensions.Height, self.m_capsuleDimensions.Radius))
		self:NKGetPhysics():NKDisableCollisions()		

		-- RA question: 
		--		1) NKSetControllerCapsuleSize isn't in the API docs--what is it?
		--		2) is this a duplicate of RigidBodyComponent.NKCreateCapsule(...)?
		-- RA question: should this be deleted for an 'ethereal' object?
		-- Set the capsule dimensions.
		self:NKSetControllerCapsuleSize(self.m_capsuleDimensions.Height, self.m_capsuleDimensions.Radius)
		
		-- How to handle movement commands from server
		self:NKGetNet():NKSetBodyInterpolationMode(EternusEngine.EInterpolationMode.eLinear)
	end

	-- RA question: do any of the following need to happen only on server or only on client?

	self:NKGetSound():NKPlay3DSound("Crystal_C", true, vec3.new(0, 0, 0), 8.0, 25.0)
	self:NKGetSound():NKPlay3DSound("Crystal_A", true, vec3.new(0, 0, 0), 8.0, 25.0)

	-- Tell the engine to trigger NavWisp:Update() every frame
	self:NKEnableScriptProcessing(true)

	-- RA question: Does this affect whether the object stays in the world between sessions?
	--				Is it necessary to set it explicitly?
	-- The wisp shouldn't be kept around. Player needs to summon it again if the game is closed
	self:NKSetShouldSave(false)
end

-------------------------------------------------------------------------------
-- Called by the engine each frame. (Assuming that self:NKEnableScriptProcessing(true) has been called)
-- RA question: is deltaTime a measure of how much time since the previous frame?
function NavWisp:Update( deltaTime )
	if NavWisp.__super.Update ~= nil then
		NavWisp.__super.Update(self, deltaTime)
	end

	-- have the wisp follow the player if it's powerful enough
	if Eternus.IsServer then
		if self.m_follow then
			local beaconTarget = self:WhichPosition(deltaTime)
			if beaconTarget == nil then
				NKWarn("RA_L] NavWisp doesn't know where to go\n")
				return
			end

			-- self:JumpToTarget(beaconTarget)
			self:MoveTowardTarget(beaconTarget, deltaTime)
			-- self:RubberbandTowardTarget(beaconTarget, deltaTime)
		end
	end
end

-------------------------------------------------------------------------------
function NavWisp:GetDisplayName()
	return self:NKGetDisplayName()
end

-------------------------------------------------------------------------------
-- Calculating beacon position
------------------------------------------------------------------------------

-------------------------------------------------------------------------------

-- DEBUG
-- While testing, use this change which style of position calculation will be used everywhere
function NavWisp:WhichPosition(deltaTime)
	-- return self:AnticipateBeaconPosition(deltaTime)  -- testing anticipation of player movement
	return self:CalculateBeaconPosition()  -- version used in Lodestaff 0.0.1
end

------------------------------------------------------------------------------
-- Where should the wisp move to in order to indicate the home direction?
-- 		If the home location is very near the player, this returns that location.
-- 		Otherwise, this calculates the angle between player and home, and returns a location
-- 		a few units down that angle from the player in the direction of the home
function NavWisp:CalculateBeaconPosition()
	if self.m_homeLocation == nil then
		NKWarn("The NavWisp has no home location.\n")
		return
	end

	-- JC a nil check is not enough to find out if the object is actually valid, you will need NKGetInstance() and then check if IsValid == true
	if self.m_player == nil or self.m_player:NKGetInstance() == nil or not self.m_player:NKGetInstance().IsValid then
		NKWarn("The NavWisp doesn't know where its player is.\n")
		return
	end

	--Get the player location, and move up several units to make it closer to eye height
	local pLocation = vec3.new(self.m_player:NKGetWorldPosition())
	pLocation = pLocation + vec3.new(0,3,0)

	-- What's the heading from player to home location?
	local homePath = self.m_homeLocation - pLocation

	local beaconTarget
	if homePath:length() <= self.m_playerdistance then
		-- RA question: does this need vec3.new()? Or just use the equals sign?
		 beaconTarget = vec3.new(self.m_homeLocation)
	else
		-- Turn the heading into a unit vector
		local unitPath = homePath:NKNormalize()

		-- Find the position m_playerdistance units along that heading
		beaconTarget = vec3.new(unitPath:mul_scalar(self.m_playerdistance) + pLocation)
	end

	-- NKPrint("[RA_L] beacon target location: "..beaconTarget:NKToString().."\n")
	return beaconTarget
end

------------------------------------------------------------------------------
-- Where should the wisp move to in order to indicate the home direction?
-- 		If the player is moving, the wisp checks their speed and anticipates
--		(very roughly) where they'll be in the next frame
function NavWisp:AnticipateBeaconPosition(deltaTime)
	if self.m_homeLocation == nil then
		NKWarn("The NavWisp has no home location.\n")
		return
	end

	-- JC a nil check is not enough to find out if the object is actually valid, 
	-- you will need NKGetInstance() and then check if IsValid == true
	if self.m_player == nil or self.m_player:NKGetInstance() == nil or not self.m_player:NKGetInstance().IsValid then
		NKWarn("The NavWisp doesn't know where its player is.\n")
		return
	end

	--Get the current player location
	local pLocation = vec3.new(self.m_player:NKGetWorldPosition())

	-- Make a guess as to where the player will be next frame
	-- (for now, just assume that the next frame time difference will 
	--	be about the same as the last)
	if deltaTime ~= nil and deltaTime ~= 0 then
		local pSpeed = 	self.m_player:NKGetCharacterController():GetSpeed()
		local pOrientation = self.m_player:NKGetWorldOrientation():Forward()
		pLocation = vec3.new(pOrientation:mul_scalar(pSpeed * deltaTime) + pLocation)
	end

	-- Move the location up several units to make it closer to eye height
	pLocation = pLocation + vec3.new(0,3,0)

	-- What's the heading from player to home location?
	local homePath = self.m_homeLocation - pLocation

	local beaconTarget
	if homePath:length() <= self.m_playerdistance then
		-- RA question: does this need vec3.new()? Or just use the equals sign?
		 beaconTarget = vec3.new(self.m_homeLocation)
	else
		-- Turn the heading into a unit vector
		local unitPath = homePath:NKNormalize()

		-- Find the position m_playerdistance units along that heading
		beaconTarget = vec3.new(unitPath:mul_scalar(self.m_playerdistance) + pLocation)
	end

	-- NKPrint("[RA_L] beacon target location: "..beaconTarget:NKToString().."\n")
	return beaconTarget
end

-------------------------------------------------------------------------------
-- Movement/animation
------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Jump the wisp directly to a specified target location
function NavWisp:JumpToTarget(targetVec3)
	-- Server handles movement, don't do anything on the client
	if Eternus.IsServer then
		-- NKPrint("[RA_L] NavWisp is starting at: "..self:NKGetWorldPosition():NKToString().."\n")

		if targetVec3 == nil then
			NKWarn("RA_L] NavWisp doesn't know where to go\n")
			return
		end

		-- Check whether we're "near enough" to the target position
		if NKMath.IsVec3Equal(self:NKGetWorldPosition(), targetVec3, NKMath.Epsilon) then
			-- NKPrint("[RA_L] NavWisp is as close as it needs to be to its target position\n")
		else
			self:NKSetPosition(targetVec3, false, false, true)
		end
	end
end

-- Animate toward a specified target location (based on AICharacter.lua v0.8.3)
-- Limits turn rate, acceleration, and speed
-- 		Calculate desired heading and distance
--		Calculate and set speed based on distance, current speed, and max acc/deceleration
--		Calculate and set heading based on desired heading and max turn rate
--		Move forward
function NavWisp:MoveTowardTarget(targetVec3, deltaTime)
	-- Server handles movement, don't do anything on the client
	if Eternus.IsServer then
		if targetVec3 == nil then
			NKWarn("RA_L] NavWisp doesn't know where to go\n")
			return
		end

		-- Does controller:MoveForward only move in the horizontal plane? 
		-- (It looks like it, so we need to handle vertical movement separately.)
		local currentPosition = self:NKGetWorldPosition()
		local vectorToTarget = targetVec3 - currentPosition
		local targetHeightChange = vectorToTarget:y()
		local horzVectorToTarget = vec3.new(vectorToTarget:x(), 0.0, vectorToTarget:z())
		local horzDistanceToTarget = horzVectorToTarget:length()
		local currentSpeed = self.m_controller:GetSpeed()
		
		-- Are we there yet? 
		-- If the character is "close enough" to the target, and moving slowly enough, 
		-- just stop right there.
		if (horzDistanceToTarget <= self.m_closeenough) and (currentSpeed <= self.m_maxdeceleration * deltaTime) then
			-- stop where we are
			self.m_controller:NKSetMaxSpeed(0)
			-- NKPrint("[RA_L] NavWisp stopped--it's as close as makes no never mind\n")
		else
			-- using local variables to stand in for a moveStyle argument
			--		probably better to pass as arguments when this gets turned back to having states
			local moveStyleTurnRate = self.m_turnrate

			-- Where does the character want to be facing?
			local desiredRotation = self:RotationToTarget(targetVec3)
			-- RA question: should we be using :NKGetOrientation() or :NKGetWorldOrientation? 
			--				(API docs imply that NKSetOrientation() is world-relative, not parent-relative)
			-- Interpolate towards our target orientation.
			-- (since the character always moves forward with regard to its orientation)
			local actualRotation = self:RotateTowards(self:NKGetOrientation(), desiredRotation, moveStyleTurnRate * deltaTime)
			self:NKSetOrientation(actualRotation, true, false)


			local moveStyleAccel = self.m_maxacceleration

			-- How fast does the character want to go? (Do we need to speed up? slow down?)
			-- In the best case, let's not try to go that distance in less than 0.1 second!
			local desiredSpeed = horzDistanceToTarget / 0.1 -- speed = distance / time
			
			-- RA question: is this a game-time-second? Or a realtime second?

			-- How much acceleration/deceleration would that take?
			local desiredAccel = (desiredSpeed - currentSpeed) -- accel = speed / time
			local allowedAccel = math.max(math.min(desiredAccel, self.m_maxacceleration), -1 * self.m_maxdeceleration)
			local allowedSpeed = math.min(self.m_maxspeed, currentSpeed + allowedAccel*1) 

			-- NKPrint("[RA_L] desired speed: "..tostring(desiredSpeed).."\n")
			-- NKPrint("[RA_L] allowed speed: "..tostring(allowedSpeed).."\n")
			
			-- Move up or down
			self.m_controller:NKSetMaxSpeed(0.1)
			if targetHeightChange > self.m_closeenough then 
				self.m_controller:MoveUp()
			elseif targetHeightChange < (-1 * self.m_closeenough) then 
				self.m_controller:MoveDown() 
			end

			-- tell the engine to commit and act on the movement instructions
			self.m_controller:Step(deltaTime)

			-- Move along the horizontal plane
			self.m_controller:NKSetMaxSpeed(allowedSpeed)
			self.m_controller:MoveForward()

			-- tell the engine to commit and act on the movement instructions
			self.m_controller:Step(deltaTime)
		end
	end
end


-------------------------------------------------------------------------------
-- Position, orientation, and location calculation
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Set the home location of the wisp: the place that it always
-- points toward, like a compass needle to north
function NavWisp:SetHomeLocation(positionVec3)
	NKPrint("[RA_L] NavWisp:SetHomeLocation called\n")
	if positionVec3 ~= nil then
		self.m_homeLocation = positionVec3

		if Eternus.IsServer then
			local beaconTarget = self:WhichPosition(0)
			-- Jump the wisp there without animation
			self:JumpToTarget(beaconTarget)
		end
	end
end

------------------------------------------------------------------------------
-- Set the player of the wisp: the person that it is always trying to stay near
-- Used for calculating where to move the wisp beacon
function NavWisp:SetPlayer(player_controller)
	NKPrint("[RA_L] NavWisp:SetPlayer called\n")
	if player_controller ~= nil then
		self.m_player = player_controller
	end
end

-------------------------------------------------------------------------------
-- Basic face the target math.
function NavWisp:RotationToTarget( pos )
	local towardsDir = self:NKGetPosition() - pos -- Backwards?
	local rot = GLM.Angle(towardsDir, NKMath.Forward)
	return rot
end

-------------------------------------------------------------------------------
-- Copied from the original
-- Returns a quat rotated from current toward target by step (in degrees).
-- Rotation is horizontal only
function NavWisp:RotateTowards( current, target, step )

	local currentDir = NKMath.Forward:mul_quat(current)
	local targetDir = NKMath.Forward:mul_quat(target)

	currentDir = vec3.new(currentDir:x(), 0.0, currentDir:z())
	targetDir = vec3.new(targetDir:x(), 0.0, targetDir:z())

	if NKMath.IsVec3Equal(currentDir, targetDir, NKMath.Epsilon) then
		if not NKMath.IsVec3Equal(targetDir, NKMath.Forward, NKMath.Epsilon) then
			return GLM.Angle( targetDir, NKMath.Forward )
		else
			return quat.new(0.0, 0.0, 0.0, 0.0)
		end
	end

	local angle = NKMath.Angle(GLM.Angle( currentDir, targetDir ), NKMath.ZeroQuat)
	local out = quat.new(current)
	if angle < 0.0 then
		GLM.Rotate(out, math.max(angle, -step), NKMath.Up)
	else
		GLM.Rotate(out, math.min(angle, step), NKMath.Up)
	end
	return out
end


------------------------------------------------------------------------------
-- Instance variable housekeeping
------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Sync object's data between client and server
-- This turns the data into an easily transferable form
function NavWisp:NetSerialize(netWriter)
	if NavWisp.__super.NetSerialize ~= nil then
		NavWisp.__super.NetSerialize(self, netWriter)
	end

	-- netWriter:NKWriteVec3(self.m_homeLocation)

	-- JC no need to sync the player, all events should be happening on the server
	--if self.m_player then
	--	netWriter:NKWriteBool(true)
	--	netWriter:NKWriteGameObject(self.m_player) -- player is a GameObject
	--else
	--	netWriter:NKWriteBool(false)
	--end
end

-------------------------------------------------------------------------------
-- Sync object's data between client and server
-- This extracts the data from its transferable form
function NavWisp:NetDeserialize(netReader)
	-- self.m_homeLocation = netReader:NKReadVec3()

	-- JC no need to sync the player, all events should be happening on the server
	--if netReader:NKReadBool() then
	--	self.m_player =    netReader:NKReadGameObject() -- player is a GameObject
	--end

	if NavWisp.__super.NetDeserialize ~= nil then
		NavWisp.__super.NetDeserialize(self, netReader)
	end
end

-------------------------------------------------------------------------------
function NavWisp:Save(outData)
	if NavWisp.__super.Save ~= nil then
		NavWisp.__super.Save(self, outData)
	end

	if (self.m_homeLocation) then
		outData.m_homeLocation = {x = self.m_homeLocation:x(),y = self.m_homeLocation:y(),z = self.m_homeLocation:z()}
	end
end

-------------------------------------------------------------------------------
function NavWisp:Restore(inData, version)
	if NavWisp.__super.Restore ~= nil then
		NavWisp.__super.Restore(self, inData, version)
	end

	if (inData.m_homeLocation) then
		self.m_homeLocation = vec3.new(inData.m_homeLocation.x,inData.m_homeLocation.y,inData.m_homeLocation.z)
	end
end


-------------------------------------------------------------------------------

EntityFramework:RegisterGameObject(NavWisp)

