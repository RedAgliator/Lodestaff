include("Scripts/Core/Common.lua")
include("Scripts/Characters/BabyCritter.lua")

local NKPhysics = include("Scripts/Core/NKPhysics.lua")
-------------------------------------------------------------------------------
-- Class BaseWisp.
BaseWisp = BabyCritter.Subclass("BaseWisp")

-------------------------------------------------------------------------------
function BaseWisp:Constructor( args )
	-- self.m_kidType = args.type

end

-------------------------------------------------------------------------------
-- Called once from the Engine after the GameObject is constructed.
function BaseWisp:PostLoad()

	-- Call super function.
	BaseWisp.__super.PostLoad(self)

	self.CritterCategory	= "Prey"
	self.CritterType 		= "Wild"
	
end

-------------------------------------------------------------------------------
-- Called by the engine when this GameObject is placed in the world.
function BaseWisp:Spawn()

	-- Call super function.
	BaseWisp.__super.Spawn(self)

	 if Eternus.IsServer then
        -- Set the controller to an entity controller(for all it's 'Rigid' properties...)
        self.m_controller:NKSwitchToEntityController(0)

        -- Set its dimensions.
        self:NKSetControllerCapsuleSize(BaseWisp.Capsule.Height, BaseWisp.Capsule.Radius)

        -- Set our initial move speed.
        self.m_controller:NKSetMaxSpeed(0.0)
        
        -- Random the initial path.
        self:Repath()

	elseif Eternus.IsClient then
		self:NKSetPhysics(RigidBodyComponent.NKCreateCapsule(self.object, self.Capsule.Height, self.Capsule.Radius))
	end

	-- set the BaseWisp textures
	self:NKGetAnimatedGraphics():NKSetSubmeshVisibility("Geo_GoatBaby", true)
	self:NKGetAnimatedGraphics():NKSetSubmeshVisibility("Geo_Goat01", false)

end

-------------------------------------------------------------------------------
-- Called by the engine each frame.
function BaseWisp:Update( dt )

	if Eternus.IsServer then
		if 	self.m_deleteMe == true then
			self:NKDeleteMe()
			return
		end
	end

    --Process the sounds for the Stalker
    self:UpdateSound(dt)

    if Eternus.IsServer then
        -- Tick the Stalker via Flee, idle, alert, or wander logic.
        self.m_state.OnUpdate(self, dt)

        -- Interpolate the speed towards the target speed.
        self:UpdateSpeed(dt)

        self:UpdateHunger(dt)
        
	    self.m_attackDelayTimeAccumulator = self.m_attackDelayTimeAccumulator + dt
	end

	-- Call super function.
	BaseWisp.__super.Update(self, dt)

end

-------------------------------------------------------------------------------
-- BaseWisp behavior used when he is actively Chasing the player.
-- The BaseWisp runs the direction selected when he entered this state.
function BaseWisp:FleeUpdate( dt )	
		
	if self.m_requestedMama == false then
		self.m_requestTimer = self.m_requestTimer + dt
		if self.m_requestTimer > 1.0 then
			Eternus.EventSystem:NKBroadcastEventInRadius("Event_CallingMamaGoat", self:NKGetPosition(), 100.0, self)	
			self.m_requestedMama = true
			self.m_requestTimer = 0.0
		end
	end

	-- Actually move the Cub.
	self:Move(dt)	
end

-------------------------------------------------------------------------------
-- A critter is being tamed
function BaseWisp:Event_BeingTamed(obj)
	if not self.m_isDead then
		if BaseWisp.IHaveAMom and BaseWisp.m_isBeingFed then
			self.m_goalObj = self:MomIsInRange()
			if self.m_goalObj ~= nil then
				local goalScript = self.m_goalObj:NKGetInstance()

				-- mom is being fed
				if goalScript.m_isBeingFed then
					self.m_isBeingFed = true
				else
					-- self.m_isBeingFed = false
				end
			else  -- no longer have a mom in range
				BaseWisp.IHaveAMom = false
				self:ChangeState(BaseWisp.AIState.Wander)
			end
		end
	end	
end

-------------------------------------------------------------------------------
function BaseWisp:Event_CallingKids(obj)
	if BaseWisp.IHaveAMom then
		BaseWisp.IHaveAMom = false
		self:ChangeState(BaseWisp.AIState.Flee)
		-- self.m_isBeingFed = false
	end
end


-------------------------------------------------------------------------------
function BaseWisp:Event_MamaGoatIsHere(obj)
	BaseWisp.IHaveAMom = true
	if not self.m_isDead and self:MomIsInRange() and not self.m_isBeingFed then
		self.m_waypoint = self.m_goalObj:NKGetPosition()

		-- Compute the distance between us and the goal obj.
		local distance = math.abs((self:NKGetPosition() - self.m_waypoint):NKLength())	
		
		if distance > 40 then 
			self:ChangeState(BaseWisp.AIState.Chase)
			return
		else
			self:ChangeState(BaseWisp.AIState.Idle)
		end
	end
end

-------------------------------------------------------------------------------
-- Check to see if there is any mamas in the area 
function BaseWisp:MomIsInRange( )

	local momList = self:GetCharactersInRadius(self.ChaseRadius)

	if momList == nil then
		return nil
	end

	local tempGoal = nil
	for key,value in pairs(momList) do

		--need to find a mama to prey
		if value:NKGetInstance() ~= nil and value:NKGetInstance():InstanceOf(MamaGoat) == true then

			if tempGoal == nil then
				tempGoal = value
			end

			--try to find our old goal
			if self.m_goalObj ~= nil and self.m_goalObj == value then
				if BaseWisp.IHaveAMom then 
					return tempGoal
				end
			end
		end
	end

	self.m_goalObj = tempGoal
	return tempGoal
end

-------------------------------------------------------------------------------
-- Check to see if there is any players in the area 
function BaseWisp:GetThreatCharacterInRange(range)

	--currently looks for predators and players

	local playerList = Eternus.World:NKGetAllWorldPlayers()

	for key, value in pairs(playerList) do
		local pawn = value:NKGetPawn()
		if pawn and pawn:NKGetInstance():InstanceOf(BasePlayer) then

			local distance = math.abs((self:NKGetPosition() - pawn:NKGetPosition()):NKLength())
			if distance <= range then
				return pawn
			end
		end
	end

	local threatList = self:GetCharactersInRadius(range)

	if not threatList then
		return nil
	end

	local tempGoal = nil
	for key,value in pairs(threatList) do

		--need to goat to prey
		if value:NKGetInstance() then

			if value:NKGetInstance():InstanceOf(Stalker) or value:NKGetInstance():InstanceOf(BearRam) then
				if not tempGoal then
					tempGoal = value
				end
			end
		end
	end

	return tempGoal

end

-- Register this class with the engine.
EntityFramework:RegisterGameObject(BaseWisp)
