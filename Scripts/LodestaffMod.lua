-- (by Red Agliator)

include("Scripts/Core/Common.lua")
include("Scripts/Characters/NavWisp.lua")
include("Scripts/Mixins/ChatCommandsInput.lua")

if LodestaffMod == nil then
	LodestaffMod = EternusEngine.ModScriptClass.Subclass("LodestaffMod")
end

-------------------------------------------------------------------------------

-- Mixins
LodestaffMod.StaticMixin(ChatCommandsInput)

-------------------------------------------------------------------------------
-- Called from C++ when a new instance of this class is created
-- Initialize member variables (default values) here
function LodestaffMod:Constructor()
end

-------------------------------------------------------------------------------
-- Called once from C++ at engine initialization time
function LodestaffMod:Initialize()
   Eternus.CraftingSystem:ParseRecipeFile("Data/Crafting/LodestaffMod_recipes.txt")

  -- Can't register custom chat commands in TUG 0.8.4 without using CommonLib
   if CommonLib ~= nil then
      -- Developer shortcuts for /spawning things for testing
      --    don't let me catch you cheating! ;)
      Eternus.GameState:RegisterSlashCommand("ls", self, "SpawnWeakLodestaff")
      Eternus.GameState:RegisterSlashCommand("ls2", self, "SpawnPowerfulLodestaff")
      Eternus.GameState:RegisterSlashCommand("lsi", self, "SpawnLodestaffIngredients")  
  end
end

-------------------------------------------------------------------------------
-- Called from C++ when the current game enters
function LodestaffMod:Enter()
end

-------------------------------------------------------------------------------
-- Called from C++ when the game leaves its current mode
function LodestaffMod:Leave()
end

-------------------------------------------------------------------------------
-- Called from C++ every update tick
function LodestaffMod:Process(dt)
end

-------------------------------------------------------------------------------
-- Custom chat command handler(s)

function LodestaffMod:SpawnWeakLodestaff(args)
  -- self:CustomSpawn("Weak Lodestaff")
  Eternus.GameState:GetLocalPlayer():SpawnCommand("Weak Lodestaff", 1, self:PositionInFrontOfPlayer())
end
function LodestaffMod:SpawnPowerfulLodestaff(args)
  Eternus.GameState:GetLocalPlayer():SpawnCommand("Powerful Lodestaff", 1, self:PositionInFrontOfPlayer())
end
function LodestaffMod:SpawnLodestaffIngredients(args)
  local position = self:PositionInFrontOfPlayer()
  Eternus.GameState:GetLocalPlayer():SpawnCommand("Wood Shaft", 1, position)
  Eternus.GameState:GetLocalPlayer():SpawnCommand("Red Mushroom Chunk", 1, position)
  Eternus.GameState:GetLocalPlayer():SpawnCommand("Orange Seeds", 1, position)
  Eternus.GameState:GetLocalPlayer():SpawnCommand("Melon Seeds", 1, position)
  Eternus.GameState:GetLocalPlayer():SpawnCommand("Dirt Clump", 1, position)
  Eternus.GameState:GetLocalPlayer():SpawnCommand("Light Green Grass Clump", 1, position)
end

-- Returns a location 2 units in front of the player and 3 units above their feet
function LodestaffMod:PositionInFrontOfPlayer()
  --player's location
  local player = Eternus.GameState:GetLocalPlayer()
  local pLocation = player:NKGetWorldPosition()
  local pVector = NKMath.Forward:mul_quat(player:NKGetWorldOrientation())
  local spawnLocation = pLocation + pVector * vec3.new(-2, 0, -2) + vec3.new(0, 3, 0)

  return spawnLocation
end


-------------------------------------------------------------------------------

EntityFramework:RegisterModScript(LodestaffMod)
