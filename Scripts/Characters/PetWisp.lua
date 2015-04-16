include("Scripts/Core/Common.lua")
include("Scripts/Characters/BaseWisp.lua")
include("Scripts/Mixins/PetCommands.lua")

local NKPhysics = include("Scripts/Core/NKPhysics.lua")
-------------------------------------------------------------------------------
-- Class PetWisp.
PetWisp = BaseWisp.Subclass("PetWisp")

-------------------------------------------------------------------------------
function PetWisp:Constructor( args )
	-- self.m_kidType = args.type
	self:Mixin(PetCommands, args)
end

-------------------------------------------------------------------------------
-- Called once from the Engine after the GameObject is constructed.
function PetWisp:PostLoad()

	-- Call super function.
	PetWisp.__super.PostLoad(self)

	self.CritterType 			= "Pet"
	self.Rank1 					= true
	self.ShouldStay 			= true
	self.CanGrowUp 				= false
	self.NextStage				= "GuardianGoat"
end

-------------------------------------------------------------------------------
-- Called by the engine when this GameObject is placed in the world.
function PetWisp:Spawn()

	-- Call super function.
	PetWisp.__super.Spawn(self)

	 if Eternus.IsServer then
        -- Set the controller to an entity controller(for all it's 'Rigid' properties...)
        self.m_controller:NKSwitchToEntityController(0)

        -- Set its dimensions.
        self:NKSetControllerCapsuleSize(PetWisp.Capsule.Height, PetWisp.Capsule.Radius)

        -- Set our initial move speed.
        self.m_controller:NKSetMaxSpeed(0.0)
        
        -- Random the initial path.
        self:Repath()

	elseif Eternus.IsClient then
		self:NKSetPhysics(RigidBodyComponent.NKCreateCapsule(self.object, self.Capsule.Height, self.Capsule.Radius))
	end

	-- set the PetWisp textures
	self:NKGetAnimatedGraphics():NKSetSubmeshVisibility("Geo_GoatBaby", true)
	self:NKGetAnimatedGraphics():NKSetSubmeshVisibility("Geo_Goat01", false)
end

-------------------------------------------------------------------------------
-- Called by the engine each frame.
function PetWisp:Update( dt )

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

	-- set up our following parameters 
	if self.m_threatCharacter == nil and self.m_playerOwner == nil then
		local threatChar = self:GetThreatCharacterInRange(self.m_playerDistanceMax)
		self:SetThreatCharacter( threatChar )
	end
	self:ChangeState(self.AIState.Follow)
	self.m_isFollowing = true

	-- start spending time with the player
	if self.CanGrowUp then
		self.m_timeInTameState = self.m_timeInTameState + dt
	end
	
	-- if we have spent enough time with the player, grow up
	if self.m_timeInTameState >= self.Rank2Time then
		-- we have aged, change to adult version
		self:GrowUp( self.m_threatCharacter, self.m_playerOwner, self.NextStage, self )
	end


	-- Call super function.
	PetWisp.__super.Update(self, dt)

end

-------------------------------------------------------------------------------
-- Check to see if there is any players in the area 
function PetWisp:GetThreatCharacterInRange(range)

	--try to find any players

	local playerList = Eternus.World:NKGetAllWorldPlayers()

	for key, value in pairs(playerList) do
		local pawn = value:NKGetPawn()
		if pawn and pawn:NKGetInstance():InstanceOf(BasePlayer) then

			local distance = math.abs((self:NKGetPosition() - pawn:NKGetPosition()):NKLength())
			if distance <= range then
				return pawn:NKGetInstance()
			end
		end
	end

	local threatList = self:GetCharactersInRadius(range)

	if not threatList then
		return nil
	end
end

-- Register this class with the engine.
EntityFramework:RegisterGameObject(PetWisp)
