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
			-- Toolbox → Creator Store → "spinning top attack" → paste MeshId
			-- meshId = "rbxassetid://0",
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
			targetSize = 3.6,
		},
		modelAssets = {
			-- meshId = "rbxassetid://0",
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
			targetSize = 3.5,
		},
		modelAssets = {
			-- meshId = "rbxassetid://0",
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
		},
	},
	{
		id = "StarfallEdge",
		name = "Starfall Edge",
		beyType = "Attack",
		color = Color3.fromRGB(220, 70, 50),
		accentColor = Color3.fromRGB(255, 150, 80),
		stats = { Attack = 9, Defense = 3, Speed = 8, Stamina = 4 },
		special = "Starfall Rush",
		specialId = "StarfallRush",
		desc = "Attack-Typ: Sternschnuppen-Salve mit Burst-Hits.",
		modelRef = {
			studioModelName = "StarfallEdge",
			targetSize = 3.5,
		},
		modelAssets = {
			-- meshId = "rbxassetid://0",
		},
	},
	{
		id = "StoneHalo",
		name = "Stone Halo",
		beyType = "Defense",
		color = Color3.fromRGB(140, 130, 115),
		accentColor = Color3.fromRGB(200, 185, 160),
		stats = { Attack = 3, Defense = 9, Speed = 4, Stamina = 9 },
		special = "Granite Bastion",
		specialId = "GraniteBastion",
		desc = "Defense-Typ: Steinmauer, Erdbeben-Pulse.",
		modelRef = {
			studioModelName = "StoneHalo",
			targetSize = 3.8,
		},
		modelAssets = {
			-- meshId = "rbxassetid://0",
		},
	},
	{
		id = "ThunderCoil",
		name = "Thunder Coil",
		beyType = "Stamina",
		color = Color3.fromRGB(60, 160, 255),
		accentColor = Color3.fromRGB(140, 220, 255),
		stats = { Attack = 5, Defense = 6, Speed = 8, Stamina = 10, SpinDecayMult = 0.6 },
		special = "Thunder Loop",
		specialId = "ThunderLoop",
		desc = "Stamina-Typ: Blitz-Spiralen und Orbit-Strike.",
		modelRef = {
			studioModelName = "ThunderCoil",
			targetSize = 3.5,
		},
		modelAssets = {
			-- meshId = "rbxassetid://0",
		},
	},
	{
		id = "NightMaw",
		name = "Night Maw",
		beyType = "Balance",
		color = Color3.fromRGB(30, 50, 70),
		accentColor = Color3.fromRGB(80, 200, 180),
		stats = { Attack = 7, Defense = 7, Speed = 5, Stamina = 7 },
		special = "Night Fang",
		specialId = "NightFang",
		desc = "Balance-Typ: Tiefsee-Dive und Frost-Burst.",
		modelRef = {
			studioModelName = "NightMaw",
			targetSize = 3.5,
		},
		modelAssets = {
			-- meshId = "rbxassetid://0",
		},
	},
}

return BeyCatalog
