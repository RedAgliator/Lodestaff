--Lodestaff object script
-- (by Red Agliator)

include("Scripts/Core/Common.lua")
include("Scripts/Objects/Equipable.lua")

include("Scripts/Characters/NavWisp")

local NKPhysics = include("Scripts/Core/NKPhysics.lua")

-------------------------------------------------------------------------------
-- Inherit the behavior from Equipable.lua
Lodestaff = Equipable.Subclass("Lodestaff")

-------------------------------------------------------------------------------
-- Mixins, if any

-- Class variables, if any (see :Constructor() for instance variables)
-- "Constants"
Lodestaff.k_weaklifespan = 3 -- the weak staff calls back the wisp after this many seconds

-------------------------------------------------------------------------------
-- Called from C++ when a new instance of this class is created
--		Initialize instance variables to defaults here
--		Read in arguments from object.txt file, if any
-- Note: when we reload scripts, we don't re-call the constructors, so changes made
-- here will not affect any currently existing objects 
function Lodestaff:Constructor( args )
	-- I don't want to deal with multiple bind locations in a stack!
	self:NKSetMaxStackCount(1) 

	-- Set instance variables to default values
	self.m_beaconWisp = nil
	self.m_bindLocation = nil
	self.m_timer = 0.0
	self.m_powerful = false
	
	-- Use the arguments section from the text file (if it exists)
	if args ~= nil then
		-- NKPrint("[RA_L] Found arguments in the definition text file:\n")
		-- -- print the argument names
		-- for k,v in pairs(args) do
		--   NKPrint("\t"..k.."\n")
		-- end

		if args.powerful then
			self.m_powerful = args.powerful
		end
	end
end

-------------------------------------------------------------------------------
-- Called once from the Engine after the GameObject is constructed.
function Lodestaff:PostLoad( )
	if Lodestaff.__super.PostLoad ~= nil then
		Lodestaff.__super.PostLoad(self)
	end

	-- Tell the engine to trigger :Update() every frame
	self:NKEnableScriptProcessing(true)
end

-------------------------------------------------------------------------------
-- Called by the engine each frame. (Assuming that self:NKEnableScriptProcessing(true) has been called)
function Lodestaff:Update( deltaTime )
	if Lodestaff.__super.Update ~= nil then
		Lodestaff.__super.Update(self)
	end

	if self.m_beaconWisp and not self.m_powerful then
		-- update the timer for the weak staff's wisp lifetime timer 
		self.m_timer = self.m_timer + deltaTime

		-- recall the wisp if its timer has run out
		if self.m_timer > self.k_weaklifespan then
			self:RecallBeacon()
		end
	end
end

-------------------------------------------------------------------------------
-- Sync object's data between client and server
-- This turns the data into an easily transferable form
function Lodestaff:NetSerialize(netWriter)	
	if Lodestaff.__super.NetSerialize ~= nil then
		Lodestaff.__super.NetSerialize(self, netWriter)
	end
	-- netWriter:NKWriteVec3(self.m_bindLocation)
end

-------------------------------------------------------------------------------
-- Sync object's data between client and server
-- This extracts the data from its transferable form
function Lodestaff:NetDeserialize(netReader)	
	-- self.m_bindLocation = netReader:NKReadVec3()
	if Lodestaff.__super.NetDeserialize ~= nil then
		Lodestaff.__super.NetDeserialize(self, netReader)
	end
end

-------------------------------------------------------------------------------
function Lodestaff:Save(outData)
	if Lodestaff.__super.Save ~= nil then
		Lodestaff.__super.Save(self, outData)
	end
	
	if (self.m_bindLocation) then
		outData.m_bindLocation = {x = self.m_bindLocation:x(),y = self.m_bindLocation:y(),z = self.m_bindLocation:z()}
	end
end

-------------------------------------------------------------------------------
function Lodestaff:Restore(inData, version)
	if Lodestaff.__super.Restore ~= nil then
		Lodestaff.__super.Restore(self, inData, version)
	end

	if (inData.m_bindLocation) then
		self.m_bindLocation = vec3.new(inData.m_bindLocation.x,inData.m_bindLocation.y,inData.m_bindLocation.z)
	end
end

-------------------------------------------------------------------------------
function Lodestaff:OnUnequip( player )
	if Lodestaff.__super.OnUnequip ~= nil then
		Lodestaff.__super.OnUnequip(self, player)
	end

	-- Get rid of wisp if there is one
	self:RecallBeacon()
end

-------------------------------------------------------------------------------
-- Called by the engine when this GameObject is placed in the world.
function Lodestaff:Spawn()
	if Lodestaff.__super.Spawn ~= nil then
		Lodestaff.__super.Spawn(self)
	end

	if self.m_bindLocation == nil then
		self.m_bindLocation = self:NKGetWorldPosition()
	end
end

-------------------------------------------------------------------------------
function Lodestaff:Despawn()
	-- Get rid of wisp if there is one
	-- RA question: is Despawn called when the player leaves the world? 
	--		If not, what is? Don't want wisp hanging around
	self:RecallBeacon()

	if Lodestaff.__super.Despawn ~= nil then
		Lodestaff.__super.Despawn(self)
	end

end

-------------------------------------------------------------------------------
-- Called when this equipable is swung by the player.
-- Called on the server side only
function Lodestaff:PrimaryAction( args )
	if Lodestaff.__super.PrimaryAction ~= nil then
		Lodestaff.__super.PrimaryAction(self, args)
	end

	-- NKPrint("[RA_L] Lodestaff was just waved.\n")

	-- RA TODECIDE
	-- child/parent relationships? with player? with staff?
	-- pass events back from wisp to the staff
	
	--Item location:
	if self.m_bindLocation == nil then
		NKWarn("The lodestaff isn't bound to any location.\n")
		return
	end

	if self.m_beaconWisp == nil then
		-- JC pass in the player that used the staff
		self:SendBeacon(args.player)
	else
		self:RecallBeacon()
	end
end

-------------------------------------------------------------------------------
-- Creating and removing the beacon wisp character
function Lodestaff:SendBeacon(player)
	if self.m_beaconWisp == nil then
		-- remove the glow from the staff
		self:NKSetEmitterActive(false)

		local whichWisp
		if self.m_powerful then
			whichWisp = "Active Lodestaff Wisp"
		else
			whichWisp = "Passive Lodestaff Wisp"
		end

		if Eternus.IsServer then
			-- create and place the beacon wisp
			local object = Eternus.GameObjectSystem:NKCreateNetworkedGameObject(whichWisp, true, true)

			if object == nil then
				NKWarn("[RA_L] Couldn't create a new lodestaff\n")
				return
			end

			-- set wisp's player before setting its location (so it knows where to go!)
			-- JC used the player passed in from PrimaryAction
			object:NKGetInstance():SetPlayer(player) 
			object:NKGetInstance():SetHomeLocation(self.m_bindLocation)
			object:NKPlaceInWorld(true, false)

			self.m_beaconWisp = object

			-- if this is a weak staff, start the wisp's timer
			if not self.m_powerful then
				self.m_timer = 0.0	
			end
		end

		-- turn off staff sound
		if self.m_ambSound ~= "" then
			self:NKGetSound():NKStop3DSound(self.m_ambSound)
		end
	end	
end

function Lodestaff:RecallBeacon()
	if self.m_beaconWisp ~= nil then
		-- remove the beacon wisp from the world
		self.m_beaconWisp:NKDeleteMe()
		self.m_beaconWisp = nil

		-- return the glow to the staff
		self:NKSetEmitterActive(true)

		-- turn on staff sound
		if self.m_ambSound ~= "" then
			self:NKGetSound():NKPlay3DSound(self.m_ambSound, true, vec3.new(2, 0, 0), 3.0, 15.0)
		end
	end
end

-------------------------------------------------------------------------------
EntityFramework:RegisterGameObject(Lodestaff)
