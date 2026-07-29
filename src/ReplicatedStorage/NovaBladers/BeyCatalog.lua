local CreatorStoreAssets = require(script.Parent.CreatorStoreAssets)

local function withStoreAssets(entry)
	local assets = CreatorStoreAssets[entry.id]
	if not assets then
		return entry
	end

	if assets.meshId then
		entry.modelAssets = {
			meshId = assets.meshId,
			textureId = assets.textureId,
			size = assets.size,
		}
	end

	if not entry.modelRef and assets.studioModelName then
		entry.modelRef = {
			studioModelName = assets.studioModelName,
			targetSize = assets.targetSize,
			importRotation = assets.importRotation,
		}
	elseif entry.modelRef and assets.studioModelName then
		entry.modelRef.studioModelName = entry.modelRef.studioModelName or assets.studioModelName
		entry.modelRef.targetSize = entry.modelRef.targetSize or assets.targetSize
		entry.modelRef.importRotation = entry.modelRef.importRotation or assets.importRotation
	end

	return entry
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
		color = Color3.fromRGB(200, 45, 55),
		accentColor = Color3.fromRGB(255, 120, 80),
		stats = { Attack = 9, Defense = 3, Speed = 8, Stamina = 4 },
		special = "Crimson Rend Claw",
		specialId = "CrimsonFangRend",
		desc = "Attack-Typ: Blitz-Slash und Dreifach-Klauen-Rend.",
	},
	{
		id = "FrostCrown",
		name = "Frost Crown",
		beyType = "Defense",
		color = Color3.fromRGB(90, 180, 230),
		accentColor = Color3.fromRGB(180, 240, 255),
		stats = { Attack = 5, Defense = 9, Speed = 4, Stamina = 7 },
		special = "Frost Crown Shatter",
		specialId = "FrostCrownShatter",
		desc = "Defense-Typ: Frost-Aura, Eisspitzen und Scherben-Burst.",
	},
}

for i, entry in BeyCatalog do
	BeyCatalog[i] = withStoreAssets(entry)
end

return BeyCatalog
