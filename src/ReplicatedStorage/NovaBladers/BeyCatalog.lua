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
			targetSize = 3.6,
			importRotation = CFrame.Angles(math.rad(-90), 0, 0),
		},
		-- Toolbox → Creator Store → "beyblade defense" / "spinning top green"
		modelAssets = {
			size = Vector3.new(3.6, 1.3, 3.6),
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
		id = "CrimsonVortex",
		name = "Crimson Vortex",
		beyType = "Attack",
		color = Color3.fromRGB(210, 55, 45),
		accentColor = Color3.fromRGB(255, 130, 55),
		stats = { Attack = 9, Defense = 3, Speed = 8, Stamina = 4 },
		special = "Crimson Spiral Strike",
		specialId = "CrimsonSpiralStrike",
		desc = "Attack-Typ: Feuer-Spirale mit mehreren Treffer-Wellen.",
		modelRef = {
			studioModelName = "CrimsonVortex",
			targetSize = 3.5,
			importRotation = CFrame.Angles(math.rad(-90), 0, 0),
		},
		-- Toolbox → Creator Store → "spinning top red" / "bey blade attack"
		modelAssets = {
			size = Vector3.new(3.5, 1.2, 3.5),
		},
	},
	{
		id = "CrystalHalo",
		name = "Crystal Halo",
		beyType = "Balance",
		color = Color3.fromRGB(70, 210, 225),
		accentColor = Color3.fromRGB(190, 255, 255),
		stats = { Attack = 6, Defense = 7, Speed = 7, Stamina = 7 },
		special = "Crystal Prism Burst",
		specialId = "CrystalPrismBurst",
		desc = "Balance-Typ: Prism-Ringe und Licht-Burst um den Gegner.",
		modelRef = {
			studioModelName = "CrystalHalo",
			targetSize = 3.6,
			importRotation = CFrame.Angles(math.rad(-90), 0, 0),
		},
		-- Toolbox → Creator Store → "crystal spinning top" / "beyblade blue"
		modelAssets = {
			size = Vector3.new(3.6, 1.1, 3.6),
		},
	},
}

return BeyCatalog
