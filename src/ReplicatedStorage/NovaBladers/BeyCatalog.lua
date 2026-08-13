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
		modelRef = {
			studioModelName = "IronShell",
		},
		modelAssets = {
			size = Vector3.new(3.8, 1.3, 3.8),
		},
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
		modelRef = {
			studioModelName = "VoltDash",
		},
		modelAssets = {
			size = Vector3.new(3.7, 1.1, 3.7),
		},
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
		modelRef = {
			studioModelName = "ShadowBite",
		},
		modelAssets = {
			size = Vector3.new(3.5, 1.2, 3.5),
		},
	},
	{
		id = "CrimsonFang",
		name = "Crimson Fang",
		beyType = "Attack",
		color = Color3.fromRGB(220, 55, 45),
		accentColor = Color3.fromRGB(255, 140, 60),
		stats = { Attack = 9, Defense = 4, Speed = 7, Stamina = 5 },
		special = "Crimson Fang Flare",
		specialId = "CrimsonFangFlare",
		desc = "Attack-Typ: Flammen-Rush und Explosions-Flare.",
		modelRef = {
			studioModelName = "CrimsonFang",
		},
		modelAssets = {
			-- meshId = "rbxassetid://",  -- Creator Store Toolbox mesh (optional)
			size = Vector3.new(3.6, 1.2, 3.6),
		},
	},
	{
		id = "FrostHalo",
		name = "Frost Halo",
		beyType = "Defense",
		color = Color3.fromRGB(120, 200, 255),
		accentColor = Color3.fromRGB(200, 240, 255),
		stats = { Attack = 4, Defense = 9, Speed = 4, Stamina = 8 },
		special = "Frost Halo Lock",
		specialId = "FrostHaloLock",
		desc = "Defense-Typ: Eisfrost-Schild und Scherben-Pulse.",
		modelRef = {
			studioModelName = "FrostHalo",
		},
		modelAssets = {
			-- meshId = "rbxassetid://",  -- Creator Store Toolbox mesh (optional)
			size = Vector3.new(3.6, 1.2, 3.6),
		},
	},
}

return BeyCatalog
