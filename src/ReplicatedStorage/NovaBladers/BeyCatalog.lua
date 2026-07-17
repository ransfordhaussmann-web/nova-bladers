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
			targetSize = 3.5,
		},
		modelAssets = {
			-- meshId = "rbxassetid://", -- Creator Store: paste MeshId here
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
	},
	{
		id = "CrimsonFang",
		name = "Crimson Fang",
		beyType = "Attack",
		color = Color3.fromRGB(200, 35, 55),
		accentColor = Color3.fromRGB(255, 80, 90),
		stats = { Attack = 9, Defense = 3, Speed = 8, Stamina = 4 },
		special = "Crimson Riptide",
		specialId = "CrimsonRiptide",
		desc = "Attack-Typ: Flutwelle, Kreisschläge und Sturzflut-Rush.",
		modelRef = {
			studioModelName = "CrimsonFang",
			targetSize = 3.5,
		},
		modelAssets = {
			-- meshId = "rbxassetid://", -- Creator Store: paste MeshId here
			size = Vector3.new(3.6, 1.2, 3.6),
		},
	},
	{
		id = "FrostCrown",
		name = "Frost Crown",
		beyType = "Defense",
		color = Color3.fromRGB(140, 210, 255),
		accentColor = Color3.fromRGB(220, 245, 255),
		stats = { Attack = 5, Defense = 7, Speed = 5, Stamina = 8, SpinDecayMult = 0.72 },
		special = "Frost Dominion",
		specialId = "FrostDominion",
		desc = "Defense-Typ: Eiskrone, Frostfeld und Scherben-Burst.",
		modelRef = {
			studioModelName = "FrostCrown",
			targetSize = 3.5,
		},
		modelAssets = {
			-- meshId = "rbxassetid://", -- Creator Store: paste MeshId here
			size = Vector3.new(3.7, 1.3, 3.7),
		},
	},
}

return BeyCatalog
