Imagine that you want to be able to always return to one particular spot in the world of TUG. Isn't there some way to tap into the energy of that area, to connect to it? To bind some of the world's neuria so that you can carry it with you but it also always stays connected to its gathering point?

The Lodestaff mod adds this ability. I wrote it so new Seedlings would have a navigation tool that is more basic than a map or return stone. The lodestaff's abilities are intentionally weak, to make up for how easy the recipes are.

First, gather materials from the local area. You're looking for things from nature, that draw on the local energies, and that maybe have a bit of vitality of their own. Oh, and you'll need a long stick to hold the combined energy! (See recipe_spoiler.txt for the details.) 

Place the materials on the spot that you want to connect to, gather energy from around you and from yourself, and weave it all together to get your lodestaff. You can see by its glow that the lodestaff now carries the energy of its birthplace.

Hold your completed lodestaff in your hand, and wave it to release a little of its energy to lead you home. If you put the lodestaff away, or wave it again, the energy will return to the staff. The energy stays with the staff, so you can put it on the ground or hand it to a friend, and it will still lead back to its birthplace. (Well, it *should*, assuming I wrote it right!)

If you can find a way to draw more neuria from nearby during the ritual, you may be able to make a more powerful version of the staff! (See recipe_spoiler.txt for the details.) 


Idea and scripting: Red Agliator


----------------------------------------------------------
CAUTION!

Single player only!

Don't stake your life or your saved game on the lodestaff! Back up your game saves before using, and be prepared to get home the normal way in case of magical failure. (In other words, I just barely got the mod working, and it's certainly riddled with bugs and completely wrong-headed ways of doing things!)



----------------------------------------------------------
INSTALLATION

Requirements:

- Version 0.8.4 of TUG. 


Where to install:

Copy the Lodestaff folder and all the files into the Mods folder inside your TUG installation. If you're using Steam:
	- Select TUG in your Steam library
	- Right-click to edit Properties 
	- Switch to the Local Files tab
	- Click the Browse Local Files button
	- Open the "Mods" folder


Enabling the mod:

Edit the file <your TUG folder>\config\mods.txt and add the following row above other similar lines:

  "Mods/Lodestaff"

So that it looks something like:

  Mods
  {
    "Mods/Lodestaff"
    "Game/Survival"
    "Game/Creative"
    "Game/Core"
  }


----------------------------------------------------------
Possibilities (no lua needed):
- Make less horrible lodestaff icons.
- Turn the staff into a fist-sized lodestone with a custom model, texture and icon
- Find or make a better ambient sound for the lodestaff wisp (don't use crystal sounds)
- Make custom model/texture/icon for a jewelry piece

Possibilities (at least some scripting need):
- Add fun trail effects to show the energy flow between the lodestaff wisp and its birthplace
- When wisp is sent out, animate its movement from the staff to its location (and vice versa)
- The staff loses durability (slowly) while the wisp is out
- Add a slight bouncing animation when the lodestaff wisp is idling
- Make it possible to craft a bound lodestone into a wearable piece of jewelry (hands-free!)
- Make wisp's up/down movement less jerky
- Make wisp truly ethereal (no collisions)
- Decide what to do with any cases where the wisp disappears into terrain and objects
- Maybe make color determined by creation biome, or nearby crystal
- Move wisp and staff sound definition into the text files for easier customization
