include("Scripts/Core/Common.lua")
include("Scripts/Characters/BaseWisp.lua")
include("Scripts/Mixins/PetCommands.lua")

local NKPhysics = include("Scripts/Core/NKPhysics.lua")
-------------------------------------------------------------------------------
-- Class Guardian Goat.
GuardianWisp = BaseWisp.Subclass("GuardianWisp")

-------------------------------------------------------------------------------
function GuardianWisp:Constructor( args )
	-- self.m_GoatType = args.type
	self:Mixin(PetCommands, args)

end

-------------------------------------------------------------------------------
-- Called once from the Engine after the GameObject is constructed.
function GuardianWisp:PostLoad()

	-- Call super function.
	GuardianWisp.__super.PostLoad(self)

	self.CritterType 			= "Guardian"
	self.Rank2 					= true
	self.ReadytoBreed 			= false
	self.MakingaBaby 			= false
	self.HasPartner 			= false
	self.m_breedMateSearch		= 0.0
	self.m_breedTimer			= 0.0
	self.m_breedBetweenTimer	= 0.0
	self.ShouldStay 			= true
	self.CanGrowUp 				= false
	self.m_babyType 			= "PetKid"
end

-------------------------------------------------------------------------------
-- Called by the engine when this GameObject is placed in the world.
function GuardianWisp:Spawn()

	-- Call super function.
	GuardianWisp.__super.Spawn(self)

	 if Eternus.IsServer then
        -- Set the controller to an entity controller(for all it's 'Rigid' properties...)
        -- self.m_controller:NKSwitchToEntityController(0)

        -- Set its dimensions.
        self:NKSetControllerCapsuleSize(GuardianWisp.Capsule.Height, GuardianWisp.Capsule.Radius)

        -- Set our initial move speed.
        -- self.m_controller:NKSetMaxSpeed(0.0)
        
        -- Random the initial path.
        -- self:Repath()

	elseif Eternus.IsClient then
		self:NKSetPhysics(RigidBodyComponent.NKCreateCapsule(self.object, self.Capsule.Height, self.Capsule.Radius))
	end

	-- set the GuardianWisp textures
	self:NKGetAnimatedGraphics():NKSetSubmeshVisibility("Geo_GoatBaby", false)
	self:NKGetAnimatedGraphics():NKSetSubmeshVisibility("Geo_Goat01", true)

end

-------------------------------------------------------------------------------
-- Called by the engine each frame.
function GuardianWisp:Update( dt )

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

	-- check to see if we need a mate
	if self.ReadytoBreed and not self.m_isDead and not self:IsFleeing() and self.m_breedTimer <= 0 and self.m_breedBetweenTimer <= 0 then
		Eternus.EventSystem:NKBroadcastEventInRadius("Event_GoatReadytoBreed", self:NKGetPosition(), 1.0, self)
	end

	-- run the breeding process
	if self.m_breedTimer > 0 then
		self.m_breedTimer = self.m_breedTimer - dt
	end

	if self.m_breedBetweenTimer > 0  then
		self.m_breedBetweenTimer = self.m_breedBetweenTimer - dt
	end

	self.m_breedMateSearch = self.m_breedMateSearch - dt
	
	if self.m_breedMateSearch <= 0 or self.m_breedBetweenTimer <= 0 then
		self.ReadytoBreed = false
		self.HasPartner = false
	end

	-- when the breed time is up, produce a baby
	if self.m_breedTimer <= 0 and self.MakingaBaby and not self.HasPartner then
		self:MakeBaby( self.m_threatCharacter, self.m_playerOwner, self.m_babyType, self )
		self.m_breedTimer = 0.0
		self.m_breedBetweenTimer = self.BreedBetweenTime
		self.MakingaBaby = false
	end

	-- Call super function.
	GuardianWisp.__super.Update(self, dt)

end

-------------------------------------------------------------------------------
-- Check to see if there is any players in the area 
function GuardianWisp:GetThreatCharacterInRange(range)

	--try to find any players

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
end

-------------------------------------------------------------------------------
-- Send out the call, we're ready to breed!
--
function GuardianWisp:Event_GoatReadytoBreed(obj)
	if not self.m_isDead and not self:IsFleeing() and self.m_breedTimer <= 0 and self.m_breedBetweenTimer <= 0  and self:NKGetInstance() ~= obj:NKGetInstance() and (self.m_playerOwner == obj.m_playerOwner) then
		local objScript = obj:NKGetInstance()
		-- turn off our flags
		self.ReadytoBreed = false
		objScript.ReadytoBreed = false
		objScript.HasPartner = true
		self.MakingaBaby = true
		self.m_breedMateSearch = 0
		objScript.m_breedMateSearch = 0
		-- start the breeding process
		self.m_breedTimer = self.BreedTime
		self:RaiseClientEvent("ClientEvent_AIPlayEmitter", {
			position = self:NKGetPosition() + self.m_healthHitEmitterOffset:mul_quat(self:NKGetOrientation()), 
			emitterName = "Default Pet Tamed Emitter"
		})
	end	
end

-- Register this class with the engine.
EntityFramework:RegisterGameObject(GuardianWisp)
