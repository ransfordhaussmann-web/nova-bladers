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
			studioModelName = "NovaStriker",
			targetSize = 3.5,
		},
		modelAssets = {
			-- Creator Store: Toolbox → meshId einfügen
			-- meshId = "rbxassetid://0",
			size = Vector3.new(3.6, 1.2, 3.6),
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
			targetSize = 3.8,
		},
		modelAssets = {
			-- meshId = "rbxassetid://0",
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
			targetSize = 3.6,
		},
		modelAssets = {
			-- meshId = "rbxassetid://0",
			size = Vector3.new(3.7, 1.0, 3.7),
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
			targetSize = 3.5,
		},
		modelAssets = {
			-- meshId = "rbxassetid://0",
			size = Vector3.new(3.5, 1.2, 3.5),
		},
	},
	{
		id = "CrimsonFang",
		name = "Crimson Fang",
		beyType = "Attack",
		color = Color3.fromRGB(210, 50, 45),
		accentColor = Color3.fromRGB(255, 120, 60),
		stats = { Attack = 9, Defense = 3, Speed = 8, Stamina = 4 },
		special = "Crimson Vortex Rip",
		specialId = "CrimsonVortexRip",
		desc = "Attack-Typ: Wirbel-Rush mit Blutungs-Hits.",
		modelRef = {
			studioModelName = "CrimsonFang",
			targetSize = 3.5,
		},
		modelAssets = {
			-- meshId = "rbxassetid://0",
			size = Vector3.new(3.6, 1.1, 3.6),
		},
	},
	{
		id = "FrostRing",
		name = "Frost Ring",
		beyType = "Defense",
		color = Color3.fromRGB(90, 170, 230),
		accentColor = Color3.fromRGB(180, 230, 255),
		stats = { Attack = 5, Defense = 9, Speed = 4, Stamina = 7 },
		special = "Frost Crystal Bastion",
		specialId = "FrostCrystalBastion",
		desc = "Defense-Typ: Eiskristall-Mauer und Frost-Schock.",
		modelRef = {
			studioModelName = "FrostRing",
			targetSize = 3.9,
		},
		modelAssets = {
			-- meshId = "rbxassetid://0",
			size = Vector3.new(3.9, 1.2, 3.9),
		},
	},
}

return BeyCatalog
