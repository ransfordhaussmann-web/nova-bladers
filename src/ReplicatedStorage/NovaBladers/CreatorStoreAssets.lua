--[[
	Optional Creator Store / Toolbox mesh IDs per Bey.
	Paste rbxassetid after importing a spinning-top model in Roblox Studio.
	Leave meshId nil to use procedural 3D layers (works out of the box).

	Studio workflow:
	1. View → Toolbox → Creator Store → search "spinning top" / "bey blade metal"
	2. Insert model, scale ~3–4 studs wide, lay flat
	3. Copy MeshId from mesh part → paste below as rbxassetid://...
	4. Or place cloned model under ReplicatedStorage/NovaBladers/Models/<studioModelName>
]]

local CreatorStoreAssets = {
	NovaStriker = {
		studioModelName = "NovaStriker",
		targetSize = 3.5,
		importRotation = CFrame.Angles(math.rad(-90), 0, 0),
		meshId = nil,
		size = Vector3.new(3.6, 1.2, 3.6),
	},
	IronShell = {
		studioModelName = "IronShell",
		targetSize = 3.8,
		importRotation = CFrame.Angles(math.rad(-90), 0, 0),
		meshId = nil,
		size = Vector3.new(3.8, 1.3, 3.8),
	},
	VoltDash = {
		studioModelName = "VoltDash",
		targetSize = 3.6,
		importRotation = CFrame.Angles(math.rad(-90), 0, 0),
		meshId = nil,
		size = Vector3.new(3.6, 1.0, 3.6),
	},
	ShadowBite = {
		studioModelName = "ShadowBite",
		targetSize = 3.5,
		importRotation = CFrame.Angles(math.rad(-90), 0, 0),
		meshId = nil,
		size = Vector3.new(3.5, 1.2, 3.5),
	},
	CrimsonFang = {
		studioModelName = "CrimsonFang",
		targetSize = 3.6,
		importRotation = CFrame.Angles(math.rad(-90), 0, 0),
		meshId = nil,
		size = Vector3.new(3.6, 1.2, 3.6),
	},
	FrostCrown = {
		studioModelName = "FrostCrown",
		targetSize = 3.9,
		importRotation = CFrame.Angles(math.rad(-90), 0, 0),
		meshId = nil,
		size = Vector3.new(3.9, 1.3, 3.9),
	},
}

return CreatorStoreAssets
