local DEFAULT_MODEL_SIZE = Vector3.new(3.6, 1.2, 3.6)

local function creatorStoreAssets(studioModelName)
	return {
		modelRef = {
			studioModelName = studioModelName,
			targetSize = 3.5,
		},
		modelAssets = {
			-- Paste Creator Store MeshId: meshId = "rbxassetid://YOUR_ID",
			size = DEFAULT_MODEL_SIZE,
		},
	}
end

local BeyCatalog = {
	{
		id = "NovaStriker",
		name = "Nova Striker",
		beyType = "Attack",
		color = Color3.fromRGB(80, 140, 255),
		accentColor = Color3.fromRGB(120, 210, 255),
		stats = { Attack = 8, Defense = 4, Speed = 7, Stamina = 5 },
		special = "Nova Meteor Shower",
		specialId = "NovaMeteorShower",
		desc = "Attack-Typ: Multi-Hit Meteor-Rush aus der Luft.",
		modelRef = {
			sketchfabId = "6bd1a9f1864a46dba4632307ce6c2660",
			sketchfabUrl = "https://sketchfab.com/models/6bd1a9f1864a46dba4632307ce6c2660",
			referenceName = "Storm Pegasus 105 RF",
			credit = "IcaroAndradeOliveira1",
			studioModelName = "NovaStriker",
			targetSize = 3.5,
		},
		modelAssets = {
			size = DEFAULT_MODEL_SIZE,
		},
	},
	{
		id = "IronShell",
		name = "Iron Shell",
		beyType = "Defense",
		color = Color3.fromRGB(80, 180, 110),
		accentColor = Color3.fromRGB(130, 255, 170),
		stats = { Attack = 4, Defense = 8, Speed = 5, Stamina = 8 },
		special = "Iron Vault Lock",
		specialId = "IronVaultLock",
		desc = "Defense-Typ: Burrow, Schutzmauer und Schockwellen.",
		modelRef = creatorStoreAssets("IronShell").modelRef,
		modelAssets = creatorStoreAssets("IronShell").modelAssets,
	},
	{
		id = "VoltDash",
		name = "Volt Dash",
		beyType = "Stamina",
		color = Color3.fromRGB(255, 200, 60),
		accentColor = Color3.fromRGB(255, 240, 120),
		stats = { Attack = 6, Defense = 5, Speed = 9, Stamina = 9, SpinDecayMult = 0.65 },
		special = "Volt Sonic Tempest",
		specialId = "VoltSonicTempest",
		desc = "Stamina-Typ: Sonic-Ringe und Orbit-Angriff.",
		modelRef = creatorStoreAssets("VoltDash").modelRef,
		modelAssets = creatorStoreAssets("VoltDash").modelAssets,
	},
	{
		id = "ShadowBite",
		name = "Shadow Bite",
		beyType = "Balance",
		color = Color3.fromRGB(140, 80, 220),
		accentColor = Color3.fromRGB(200, 100, 255),
		stats = { Attack = 7, Defense = 6, Speed = 6, Stamina = 6 },
		special = "Shadow Eclipse Fang",
		specialId = "ShadowEclipseFang",
		desc = "Balance-Typ: Dark-Aura, Dive und Venom-Burst.",
		modelRef = creatorStoreAssets("ShadowBite").modelRef,
		modelAssets = creatorStoreAssets("ShadowBite").modelAssets,
	},
	{
		id = "EmberCore",
		name = "Ember Core",
		beyType = "Attack",
		color = Color3.fromRGB(230, 70, 40),
		accentColor = Color3.fromRGB(255, 160, 50),
		stats = { Attack = 9, Defense = 3, Speed = 8, Stamina = 4 },
		special = "Inferno Spiral",
		specialId = "InfernoSpiral",
		desc = "Attack-Typ: Feuer-Spirale mit schnellen Meteor-Hits.",
		modelRef = creatorStoreAssets("EmberCore").modelRef,
		modelAssets = creatorStoreAssets("EmberCore").modelAssets,
	},
	{
		id = "FrostCrown",
		name = "Frost Crown",
		beyType = "Defense",
		color = Color3.fromRGB(100, 180, 230),
		accentColor = Color3.fromRGB(200, 240, 255),
		stats = { Attack = 4, Defense = 9, Speed = 5, Stamina = 7 },
		special = "Glacier Bastion",
		specialId = "GlacierBastion",
		desc = "Defense-Typ: Eis-Bunker, Frostwand und Kälte-Pulse.",
		modelRef = creatorStoreAssets("FrostCrown").modelRef,
		modelAssets = creatorStoreAssets("FrostCrown").modelAssets,
	},
}

return BeyCatalog
