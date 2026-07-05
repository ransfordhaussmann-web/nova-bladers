local DEFAULT_MODEL_ASSETS = {
	meshId = nil, -- rbxassetid://… nach Creator-Store-Import in Studio
	size = Vector3.new(3.6, 1.2, 3.6),
}

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
		creatorStore = {
			searchTerms = { "spinning top", "pegasus", "attack top" },
			notes = "Flache Spin-Top-Mesh, ~3–4 Studs breit",
		},
		modelAssets = {
			meshId = nil,
			size = Vector3.new(3.6, 1.2, 3.6),
		},
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
		creatorStore = {
			searchTerms = { "spinning top", "defense", "metal top" },
			notes = "Schwerer Ring-Look, grün/metallisch",
		},
		modelAssets = table.clone(DEFAULT_MODEL_ASSETS),
		modelRef = {
			studioModelName = "IronShell",
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
		creatorStore = {
			searchTerms = { "spinning top", "lightning", "speed top" },
			notes = "Flacher breiter Ring, gelb/gold",
		},
		modelAssets = table.clone(DEFAULT_MODEL_ASSETS),
		modelRef = {
			studioModelName = "VoltDash",
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
		creatorStore = {
			searchTerms = { "spinning top", "dark", "fang top" },
			notes = "Asymmetrische Klingen, lila/dunkel",
		},
		modelAssets = table.clone(DEFAULT_MODEL_ASSETS),
		modelRef = {
			studioModelName = "ShadowBite",
		},
	},
	{
		id = "CrimsonFang",
		name = "Crimson Fang",
		beyType = "Attack",
		color = Color3.fromRGB(200, 40, 55),
		accentColor = Color3.fromRGB(255, 90, 70),
		stats = { Attack = 9, Defense = 3, Speed = 8, Stamina = 4 },
		special = "Crimson Scythe Barrage",
		specialId = "CrimsonScytheBarrage",
		desc = "Attack-Typ: Sensen-Salve mit hohem Burst-Schaden.",
		creatorStore = {
			searchTerms = { "spinning top", "scythe", "red blade top" },
			notes = "Scharfe Klingen, rot/karmin",
		},
		modelAssets = table.clone(DEFAULT_MODEL_ASSETS),
		modelRef = {
			studioModelName = "CrimsonFang",
		},
	},
	{
		id = "FrostCore",
		name = "Frost Core",
		beyType = "Defense",
		color = Color3.fromRGB(90, 170, 230),
		accentColor = Color3.fromRGB(180, 230, 255),
		stats = { Attack = 3, Defense = 9, Speed = 4, Stamina = 9 },
		special = "Frost Bastion",
		specialId = "FrostBastion",
		desc = "Defense-Typ: Eis-Festung, Frostwellen und Schutz.",
		creatorStore = {
			searchTerms = { "spinning top", "ice", "crystal top" },
			notes = "Kristall-/Eis-Look, blau/weiß",
		},
		modelAssets = table.clone(DEFAULT_MODEL_ASSETS),
		modelRef = {
			studioModelName = "FrostCore",
		},
	},
}

return BeyCatalog
