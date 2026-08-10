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
		modelAssets = {
			-- Creator Store: Toolbox → "spinning top" / "attack blade"
			-- meshId = "rbxassetid://YOUR_ID",
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
		},
		modelAssets = {
			-- Creator Store: Toolbox → "defense bey" / "metal shell"
			-- meshId = "rbxassetid://YOUR_ID",
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
			-- Creator Store: Toolbox → "stamina ring" / "flat spin top"
			-- meshId = "rbxassetid://YOUR_ID",
			size = Vector3.new(3.9, 1.0, 3.9),
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
			-- Creator Store: Toolbox → "balance blade" / "dark spin"
			-- meshId = "rbxassetid://YOUR_ID",
			size = Vector3.new(3.6, 1.2, 3.6),
		},
	},
	{
		id = "CrimsonRipper",
		name = "Crimson Ripper",
		beyType = "Attack",
		color = Color3.fromRGB(210, 45, 40),
		accentColor = Color3.fromRGB(255, 120, 60),
		stats = { Attack = 9, Defense = 3, Speed = 8, Stamina = 4 },
		special = "Crimson Vortex Slash",
		specialId = "CrimsonVortexSlash",
		desc = "Attack-Typ: Rotierender Vortex-Rush mit Säge-Klingen.",
		modelRef = {
			studioModelName = "CrimsonRipper",
		},
		modelAssets = {
			-- Creator Store: Toolbox → "saw blade" / "crimson spin top"
			-- meshId = "rbxassetid://YOUR_ID",
			size = Vector3.new(3.6, 1.2, 3.6),
		},
	},
	{
		id = "FrostMonarch",
		name = "Frost Monarch",
		beyType = "Defense",
		color = Color3.fromRGB(90, 170, 240),
		accentColor = Color3.fromRGB(200, 235, 255),
		stats = { Attack = 3, Defense = 9, Speed = 5, Stamina = 8 },
		special = "Frost Citadel",
		specialId = "FrostCitadel",
		desc = "Defense-Typ: Eis-Festung, Frostwellen und Schutz.",
		modelRef = {
			studioModelName = "FrostMonarch",
		},
		modelAssets = {
			-- Creator Store: Toolbox → "ice crystal" / "frost shield top"
			-- meshId = "rbxassetid://YOUR_ID",
			size = Vector3.new(3.8, 1.3, 3.8),
		},
	},
}

return BeyCatalog
